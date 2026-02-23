//
//  ChatHistoryItemTests.swift
//  copilot-islandTests
//
//  Tests for ChatHistoryItem model
//

import XCTest
@testable import copilot_island

final class ChatHistoryItemTests: XCTestCase {

    // MARK: - Test Initialization

    func testInitWithDefaultTimestamp() {
        let before = Date()
        let item = ChatHistoryItem(id: "test-id", type: .user("Hello"))
        let after = Date()

        XCTAssertEqual(item.id, "test-id")
        XCTAssertEqual(item.type, .user("Hello"))
        XCTAssertGreaterThanOrEqual(item.timestamp, before)
        XCTAssertLessThanOrEqual(item.timestamp, after)
    }

    func testInitWithCustomTimestamp() {
        let customDate = Date(timeIntervalSince1970: 1704067200)
        let item = ChatHistoryItem(id: "test-id", type: .assistant("Response"), timestamp: customDate)

        XCTAssertEqual(item.id, "test-id")
        XCTAssertEqual(item.type, .assistant("Response"))
        XCTAssertEqual(item.timestamp, customDate)
    }

    func testInitWithAllTypes() {
        let userItem = ChatHistoryItem(id: "1", type: .user("Hello"))
        let assistantItem = ChatHistoryItem(id: "2", type: .assistant("Hi there"))
        let toolItem = ChatHistoryItem(id: "3", type: .toolCall(ToolCallItem(id: "tool-1", name: "bash", input: [:], status: .running, result: nil)))
        let thinkingItem = ChatHistoryItem(id: "4", type: .thinking("Thinking..."))

        XCTAssertEqual(userItem.type, .user("Hello"))
        XCTAssertEqual(assistantItem.type, .assistant("Hi there"))
        XCTAssertNotNil(toolItem.type.toolCallVal)
        XCTAssertEqual(thinkingItem.type, .thinking("Thinking..."))
    }

    // MARK: - Test Equatable

    func testEquatableSameIdAndType() {
        let item1 = ChatHistoryItem(id: "test-id", type: .user("Hello"))
        let item2 = ChatHistoryItem(id: "test-id", type: .user("Hello"))

        XCTAssertEqual(item1, item2)
    }

    func testEquatableDifferentId() {
        let item1 = ChatHistoryItem(id: "test-id-1", type: .user("Hello"))
        let item2 = ChatHistoryItem(id: "test-id-2", type: .user("Hello"))

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableDifferentType() {
        let item1 = ChatHistoryItem(id: "test-id", type: .user("Hello"))
        let item2 = ChatHistoryItem(id: "test-id", type: .assistant("Hello"))

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableSameIdDifferentContent() {
        let item1 = ChatHistoryItem(id: "test-id", type: .user("Hello"))
        let item2 = ChatHistoryItem(id: "test-id", type: .user("Different"))

        XCTAssertNotEqual(item1, item2)
    }

    // MARK: - Test Different Chat History Types

    func testUserType() {
        let item = ChatHistoryItem(id: "1", type: .user("What is Swift?"))

        if case .user(let content) = item.type {
            XCTAssertEqual(content, "What is Swift?")
        } else {
            XCTFail("Expected user type")
        }
    }

    func testAssistantType() {
        let item = ChatHistoryItem(id: "1", type: .assistant("Swift is a programming language."))

        if case .assistant(let content) = item.type {
            XCTAssertEqual(content, "Swift is a programming language.")
        } else {
            XCTFail("Expected assistant type")
        }
    }

    func testThinkingType() {
        let item = ChatHistoryItem(id: "1", type: .thinking("Let me analyze this..."))

        if case .thinking(let content) = item.type {
            XCTAssertEqual(content, "Let me analyze this...")
        } else {
            XCTFail("Expected thinking type")
        }
    }

    func testToolCallType() {
        let toolCall = ToolCallItem(id: "tool-1", name: "bash", input: ["command": "ls"], status: .success, result: "file1\nfile2")
        let item = ChatHistoryItem(id: "1", type: .toolCall(toolCall))

        if case .toolCall(let toolItem) = item.type {
            XCTAssertEqual(toolItem.name, "bash")
            XCTAssertEqual(toolItem.status, .success)
        } else {
            XCTFail("Expected toolCall type")
        }
    }
}

// Extension to access toolCall associated value for testing
extension ChatHistoryItemType {
    var toolCallVal: ToolCallItem? {
        if case .toolCall(let item) = self {
            return item
        }
        return nil
    }
}
