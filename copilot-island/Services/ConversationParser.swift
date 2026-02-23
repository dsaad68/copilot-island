//
//  ConversationParser.swift
//  CopilotIsland
//
//  Parses events.jsonl files from Copilot CLI session state
//

import Foundation

actor ConversationParser {

    struct ParseResult: Sendable {
        let items: [ChatHistoryItem]
        let lastOffset: UInt64
    }

    private var fileOffsets: [String: UInt64] = [:]

    func parseEventsFile(at path: String) -> ParseResult {
        guard let fileHandle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return ParseResult(items: [], lastOffset: 0)
        }

        defer { try? fileHandle.close() }

        let offset = fileOffsets[path] ?? 0
        if offset > 0 {
            try? fileHandle.seek(toOffset: offset)
        }

        var items: [ChatHistoryItem] = []
        var currentToolCalls: [String: (name: String, input: [String: String], startTime: Date)] = [:]

        let data = fileHandle.readDataToEndOfFile()
        if let text = String(data: data, encoding: .utf8) {
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty,
                      let jsonData = trimmed.data(using: .utf8) else { continue }

                if let parsed = parseEventLine(jsonData, currentToolCalls: &currentToolCalls) {
                    items.append(contentsOf: parsed)
                }
            }
        }

        // Emit any unfinished tool calls as .running
        for (toolCallId, pending) in currentToolCalls {
            let toolItem = ToolCallItem(
                id: toolCallId,
                name: pending.name,
                input: pending.input,
                status: .running,
                result: nil
            )
            items.append(ChatHistoryItem(id: toolCallId, type: .toolCall(toolItem), timestamp: pending.startTime))
        }

        let newOffset = (try? fileHandle.offsetInFile) ?? offset
        fileOffsets[path] = newOffset

        return ParseResult(items: items, lastOffset: newOffset)
    }

    func parseFullFile(at path: String) -> [ChatHistoryItem] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return []
        }

        var items: [ChatHistoryItem] = []
        var currentToolCalls: [String: (name: String, input: [String: String], startTime: Date)] = [:]

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let jsonData = trimmed.data(using: .utf8) else { continue }

            if let parsed = parseEventLine(jsonData, currentToolCalls: &currentToolCalls) {
                items.append(contentsOf: parsed)
            }
        }

        // Emit any unfinished tool calls as .running
        for (toolCallId, pending) in currentToolCalls {
            let toolItem = ToolCallItem(
                id: toolCallId,
                name: pending.name,
                input: pending.input,
                status: .running,
                result: nil
            )
            items.append(ChatHistoryItem(id: toolCallId, type: .toolCall(toolItem), timestamp: pending.startTime))
        }

        return items
    }

    private func parseEventLine(_ data: Data, currentToolCalls: inout [String: (name: String, input: [String: String], startTime: Date)]) -> [ChatHistoryItem]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return nil }

        let timestampStr = json["timestamp"] as? String
        let timestamp = ISO8601DateFormatter().date(from: timestampStr ?? "") ?? Date()
        let id = json["id"] as? String ?? UUID().uuidString

        switch type {
        case "user.message":
            guard let data = json["data"] as? [String: Any],
                  let content = data["content"] as? String else { return nil }
            return [ChatHistoryItem(id: id, type: .user(content), timestamp: timestamp)]

        case "assistant.message":
            guard let data = json["data"] as? [String: Any] else { return nil }
            let content = data["content"] as? String ?? ""

            var items: [ChatHistoryItem] = []

            // Extract reasoning text (collapsible thinking) if present
            if let reasoning = data["reasoningText"] as? String, !reasoning.isEmpty {
                items.append(ChatHistoryItem(
                    id: "\(id)-thinking",
                    type: .thinking(reasoning),
                    timestamp: timestamp
                ))
            }

            if !content.isEmpty {
                items.append(ChatHistoryItem(id: id, type: .assistant(content), timestamp: timestamp))
            }

            return items.isEmpty ? nil : items

        case "tool.execution_start":
            guard let data = json["data"] as? [String: Any],
                  let toolCallId = data["toolCallId"] as? String,
                  let toolName = data["toolName"] as? String else { return nil }

            let args = data["arguments"] as? [String: Any] ?? [:]
            let input = args.mapValues { String(describing: $0) }

            // Store but do NOT emit yet — wait for execution_complete
            currentToolCalls[toolCallId] = (name: toolName, input: input, startTime: timestamp)
            return nil

        case "tool.execution_complete":
            guard let data = json["data"] as? [String: Any],
                  let toolCallId = data["toolCallId"] as? String else { return nil }

            let existingCall = currentToolCalls.removeValue(forKey: toolCallId)
            let toolName = existingCall?.name ?? (data["toolName"] as? String ?? "unknown")
            let input = existingCall?.input ?? [:]

            let success = data["success"] as? Bool ?? false
            let resultData = data["result"] as? [String: Any]
            let resultContent = resultData?["content"] as? String ?? resultData?["detailedContent"] as? String

            let status: ToolStatus
            if success {
                status = .success
            } else {
                let errorData = data["error"] as? [String: Any]
                let errorMsg = errorData?["message"] as? String
                status = .error(errorMsg)
            }

            let toolItem = ToolCallItem(
                id: toolCallId,
                name: toolName,
                input: input,
                status: status,
                result: resultContent
            )
            return [ChatHistoryItem(id: id, type: .toolCall(toolItem), timestamp: timestamp)]

        default:
            return nil
        }
    }
}
