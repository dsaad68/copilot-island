//
//  CopilotEventTests.swift
//  copilot-islandTests
//
//  Tests for CopilotEvent model
//

import XCTest
@testable import copilot_island

final class CopilotEventTests: XCTestCase {

    // MARK: - Test Codable for preToolUse

    func testPreToolUseCodable() throws {
        let event = CopilotEvent(
            event: .preToolUse,
            timestamp: 1704067200,
            cwd: "/Users/test/project",
            reason: nil,
            toolName: "bash",
            toolArgs: "ls -la"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CopilotEvent.self, from: data)

        XCTAssertEqual(decoded.event, .preToolUse)
        XCTAssertEqual(decoded.timestamp, 1704067200)
        XCTAssertEqual(decoded.cwd, "/Users/test/project")
        XCTAssertNil(decoded.reason)
        XCTAssertEqual(decoded.toolName, "bash")
        XCTAssertEqual(decoded.toolArgs, "ls -la")
    }

    func testPreToolUseJSONParsing() throws {
        let json = """
        {
            "event": "preToolUse",
            "timestamp": 1704067200,
            "cwd": "/Users/test/project",
            "toolName": "git",
            "toolArgs": "commit -m \\"test\\""
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let event = try decoder.decode(CopilotEvent.self, from: json)

        XCTAssertEqual(event.event, .preToolUse)
        XCTAssertEqual(event.toolName, "git")
        XCTAssertEqual(event.toolArgs, "commit -m \"test\"")
    }

    // MARK: - Test Codable for sessionEnd

    func testSessionEndCodable() throws {
        let event = CopilotEvent(
            event: .sessionEnd,
            timestamp: 1704067200,
            cwd: "/Users/test/project",
            reason: "complete",
            toolName: nil,
            toolArgs: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CopilotEvent.self, from: data)

        XCTAssertEqual(decoded.event, .sessionEnd)
        XCTAssertEqual(decoded.timestamp, 1704067200)
        XCTAssertEqual(decoded.cwd, "/Users/test/project")
        XCTAssertEqual(decoded.reason, "complete")
    }

    func testSessionEndJSONParsing() throws {
        let json = """
        {
            "event": "sessionEnd",
            "timestamp": 1704067200,
            "cwd": "/Users/test/project",
            "reason": "user_cancelled"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let event = try decoder.decode(CopilotEvent.self, from: json)

        XCTAssertEqual(event.event, .sessionEnd)
        XCTAssertEqual(event.reason, "user_cancelled")
    }

    // MARK: - Test EventType Enum

    func testEventTypeRawValues() {
        XCTAssertEqual(CopilotEvent.EventType.preToolUse.rawValue, "preToolUse")
        XCTAssertEqual(CopilotEvent.EventType.sessionEnd.rawValue, "sessionEnd")
    }

    func testEventTypeDecoding() throws {
        let preToolUseData = "\"preToolUse\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CopilotEvent.EventType.self, from: preToolUseData)
        XCTAssertEqual(decoded, .preToolUse)

        let sessionEndData = "\"sessionEnd\"".data(using: .utf8)!
        let decoded2 = try JSONDecoder().decode(CopilotEvent.EventType.self, from: sessionEndData)
        XCTAssertEqual(decoded2, .sessionEnd)
    }

    // MARK: - Test Full Event with All Fields

    func testFullEventWithAllFields() throws {
        let json = """
        {
            "event": "preToolUse",
            "timestamp": 1704067200,
            "cwd": "/Users/test/project",
            "reason": null,
            "toolName": "bash",
            "toolArgs": "echo \\"Hello World\\""
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CopilotEvent.self, from: json)

        XCTAssertEqual(event.event, .preToolUse)
        XCTAssertEqual(event.timestamp, 1704067200)
        XCTAssertEqual(event.cwd, "/Users/test/project")
        XCTAssertNil(event.reason)
        XCTAssertEqual(event.toolName, "bash")
        XCTAssertEqual(event.toolArgs, "echo \"Hello World\"")
    }

    // MARK: - Test Edge Cases

    func testEventWithEmptyCwd() throws {
        let json = """
        {
            "event": "sessionEnd",
            "timestamp": 1704067200,
            "cwd": "",
            "reason": "complete"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CopilotEvent.self, from: json)
        XCTAssertEqual(event.cwd, "")
    }

    func testEventWithNullToolName() throws {
        let json = """
        {
            "event": "preToolUse",
            "timestamp": 1704067200,
            "cwd": "/test",
            "toolName": null,
            "toolArgs": null
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CopilotEvent.self, from: json)
        XCTAssertNil(event.toolName)
        XCTAssertNil(event.toolArgs)
    }

    func testEventWithZeroTimestamp() throws {
        let json = """
        {
            "event": "sessionEnd",
            "timestamp": 0,
            "cwd": "/test",
            "reason": "complete"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(CopilotEvent.self, from: json)
        XCTAssertEqual(event.timestamp, 0)
    }

    // MARK: - Test Encoding

    func testPreToolUseEncoding() throws {
        let event = CopilotEvent(
            event: .preToolUse,
            timestamp: 1704067200,
            cwd: "/test",
            reason: nil,
            toolName: "bash",
            toolArgs: "ls"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"event\":\"preToolUse\""))
        XCTAssertTrue(jsonString.contains("\"toolName\":\"bash\""))
    }

    func testSessionEndEncoding() throws {
        let event = CopilotEvent(
            event: .sessionEnd,
            timestamp: 1704067200,
            cwd: "/test",
            reason: "complete",
            toolName: nil,
            toolArgs: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"event\":\"sessionEnd\""))
        XCTAssertTrue(jsonString.contains("\"reason\":\"complete\""))
    }
}
