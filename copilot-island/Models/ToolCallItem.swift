//
//  ToolCallItem.swift
//  CopilotIsland
//
//  Represents a tool call in chat history
//

import Foundation

struct ToolCallItem: Equatable, Sendable {
    let id: String
    let name: String
    let input: [String: String]
    var status: ToolStatus
    var result: String?
    
    var statusDisplay: String {
        switch status {
        case .running: return "Running"
        case .success: return "Success"
        case .error(let msg): return msg ?? "Error"
        }
    }
    
    var inputPreview: String {
        if input.isEmpty { return "" }
        let keys = input.keys.sorted()
        let parts = keys.prefix(3).map { "\($0): \(input[$0] ?? "")" }
        let preview = parts.joined(separator: ", ")
        return input.count > 3 ? "\(preview)..." : preview
    }
}
