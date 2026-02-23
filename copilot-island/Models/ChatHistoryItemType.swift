//
//  ChatHistoryItemType.swift
//  CopilotIsland
//
//  Types of items in chat history
//

import Foundation

enum ChatHistoryItemType: Equatable, Sendable {
    case user(String)
    case assistant(String)
    case toolCall(ToolCallItem)
    case thinking(String)
}
