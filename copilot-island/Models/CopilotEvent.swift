//
//  CopilotEvent.swift
//  CopilotIsland
//
//  Events received from Copilot CLI hook scripts via Unix socket.
//  Only preToolUse and sessionEnd are still sent via socket —
//  all other state is driven by SessionWatcher via events.jsonl.
//

import Foundation

struct CopilotEvent: Codable, Sendable {
    let event: EventType
    let timestamp: Int64
    let cwd: String

    let reason: String?
    let toolName: String?
    let toolArgs: String?

    enum EventType: String, Codable {
        case preToolUse
        case sessionEnd
    }
}
