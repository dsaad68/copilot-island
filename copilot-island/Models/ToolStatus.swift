//
//  ToolStatus.swift
//  CopilotIsland
//
//  Status of a tool execution
//

import Foundation

enum ToolStatus: Equatable, Sendable {
    case running
    case success
    case error(String?)
}
