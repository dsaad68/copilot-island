//
//  SessionPhase.swift
//  CopilotIsland
//
//  Represents the current phase of a Copilot session
//

import Foundation

enum SessionPhase: Equatable {
    case idle
    case processing
    case runningTool(name: String)
    case waitingForApproval(toolName: String)
    case error(message: String)
    case ended(reason: String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }

    var isRunningTool: Bool {
        if case .runningTool = self { return true }
        return false
    }

    var isWaitingForApproval: Bool {
        if case .waitingForApproval = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var isEnded: Bool {
        if case .ended = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .idle:
            return "Ready"
        case .processing:
            return "Processing..."
        case .runningTool(let name):
            return "Running \(name)"
        case .waitingForApproval(let toolName):
            return "Approve \(toolName)?"
        case .error(let message):
            return "Error: \(message)"
        case .ended(let reason):
            return "Ended (\(reason))"
        }
    }
}
