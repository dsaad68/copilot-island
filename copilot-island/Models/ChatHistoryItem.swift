//
//  ChatHistoryItem.swift
//  CopilotIsland
//
//  Single item in chat history
//

import Foundation

struct ChatHistoryItem: Identifiable, Equatable, Sendable {
    let id: String
    let type: ChatHistoryItemType
    let timestamp: Date
    
    init(id: String = UUID().uuidString, type: ChatHistoryItemType, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
    }

    static func == (lhs: ChatHistoryItem, rhs: ChatHistoryItem) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }
}
