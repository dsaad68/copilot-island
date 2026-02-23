//
//  HistoricalSession.swift
//  CopilotIsland
//
//  Represents a past Copilot session loaded from ~/.copilot/session-state/
//

import Foundation

struct HistoricalSession: Identifiable, Equatable {
    let id: String           // UUID from directory name
    let summary: String?     // from workspace.yaml "summary:" field
    let cwd: String          // from workspace.yaml "cwd:" field
    let repository: String?  // from workspace.yaml "repository:" field
    let branch: String?      // from workspace.yaml "branch:" field
    let createdAt: Date
    let updatedAt: Date
    let lastMessage: String?
    
    static func == (lhs: HistoricalSession, rhs: HistoricalSession) -> Bool {
        lhs.id == rhs.id
    } // last user.message content from events.jsonl

    /// Display title: summary if available, otherwise the last path component of cwd
    var displayTitle: String {
        if let summary, !summary.isEmpty { return summary }
        return (cwd as NSString).lastPathComponent
    }

    // MARK: - Loading

    static let sessionStateDir: URL = {
        let home: URL
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        } else {
            home = URL(fileURLWithPath: "/Users/\(NSUserName())", isDirectory: true)
        }
        return home.appendingPathComponent(".copilot/session-state")
    }()

    /// Load recent sessions from ~/.copilot/session-state/, sorted by updatedAt descending
    static func loadRecent(limit: Int = 10) -> [HistoricalSession] {
        let fm = FileManager.default
        let baseDir = sessionStateDir

        guard let entries = try? fm.contentsOfDirectory(atPath: baseDir.path) else {
            return []
        }

        var sessions: [HistoricalSession] = []

        for entry in entries {
            let dir = baseDir.appendingPathComponent(entry)
            let workspacePath = dir.appendingPathComponent("workspace.yaml").path

            guard fm.fileExists(atPath: workspacePath) else { continue }

            if let session = parse(directory: dir, id: entry) {
                sessions.append(session)
            }
        }

        return Array(
            sessions.sorted { $0.updatedAt > $1.updatedAt }
                .prefix(limit)
        )
    }

    private static func parse(directory: URL, id: String) -> HistoricalSession? {
        let fm = FileManager.default
        let workspacePath = directory.appendingPathComponent("workspace.yaml").path

        guard let content = try? String(contentsOfFile: workspacePath, encoding: .utf8) else {
            return nil
        }

        let fields = parseYaml(content)
        guard let cwd = fields["cwd"], !cwd.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let attrs = try? fm.attributesOfItem(atPath: workspacePath)

        let createdAt: Date
        if let str = fields["created_at"], let parsed = isoFormatter.date(from: str) {
            createdAt = parsed
        } else {
            createdAt = attrs?[.creationDate] as? Date ?? Date.distantPast
        }

        let updatedAt: Date
        let eventsPath = directory.appendingPathComponent("events.jsonl").path
        if let eventsAttrs = try? fm.attributesOfItem(atPath: eventsPath),
           let eventsModified = eventsAttrs[.modificationDate] as? Date {
            updatedAt = eventsModified
        } else if let str = fields["updated_at"], let parsed = isoFormatter.date(from: str) {
            updatedAt = parsed
        } else {
            updatedAt = attrs?[.modificationDate] as? Date ?? Date.distantPast
        }

        let lastMessage = readLastUserMessage(
            from: directory.appendingPathComponent("events.jsonl").path
        )

        return HistoricalSession(
            id: id,
            summary: fields["summary"],
            cwd: cwd,
            repository: fields["repository"],
            branch: fields["branch"],
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessage: lastMessage
        )
    }

    /// Simple line-by-line YAML parser for flat key: value files
    private static func parseYaml(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex])
                .trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private static func readLastUserMessage(from path: String) -> String? {
        guard let data = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        let lines = data.components(separatedBy: .newlines).reversed()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let jsonData = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            if let type = obj["type"] as? String, type == "user.message",
               let eventData = obj["data"] as? [String: Any],
               let content = eventData["content"] as? String {
                return String(content.prefix(120))
            }
        }
        return nil
    }
}
