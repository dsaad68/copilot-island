//
//  ConversationParserTests.swift
//  copilot-islandTests
//
//  Tests for ConversationParser service
//

import XCTest
@testable import copilot_island

final class ConversationParserTests: XCTestCase {

    var parser: ConversationParser!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        parser = ConversationParser()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Test parseFullFile

    func testParseUserMessage() async throws {
        let eventsContent = """
        {"type":"user.message","data":{"content":"Hello"},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 1)
        if case .user(let content) = items[0].type {
            XCTAssertEqual(content, "Hello")
        } else {
            XCTFail("Expected user message")
        }
    }

    func testParseAssistantMessage() async throws {
        let eventsContent = """
        {"type":"assistant.message","data":{"content":"Hi there!"},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 1)
        if case .assistant(let content) = items[0].type {
            XCTAssertEqual(content, "Hi there!")
        } else {
            XCTFail("Expected assistant message")
        }
    }

    func testParseThinkingContent() async throws {
        let eventsContent = """
        {"type":"assistant.message","data":{"content":"Answer","reasoningText":"Thinking process..."},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 2)

        if case .thinking(let reasoning) = items[0].type {
            XCTAssertEqual(reasoning, "Thinking process...")
        } else {
            XCTFail("Expected thinking message")
        }

        if case .assistant(let content) = items[1].type {
            XCTAssertEqual(content, "Answer")
        } else {
            XCTFail("Expected assistant message")
        }
    }

    func testParseToolExecutionComplete() async throws {
        let eventsContent = """
        {"type":"tool.execution_start","data":{"toolCallId":"call_1","toolName":"bash","arguments":{"command":"ls"}},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        {"type":"tool.execution_complete","data":{"toolCallId":"call_1","success":true,"result":{"content":"file1\\nfile2"}},"id":"2","timestamp":"2026-01-01T12:00:02Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 1)

        if case .toolCall(let toolItem) = items[0].type {
            XCTAssertEqual(toolItem.id, "call_1")
            XCTAssertEqual(toolItem.name, "bash")
            XCTAssertEqual(toolItem.status, .success)
            XCTAssertEqual(toolItem.result, "file1\nfile2")
        } else {
            XCTFail("Expected tool call")
        }
    }

    func testParseToolExecutionWithError() async throws {
        let eventsContent = """
        {"type":"tool.execution_start","data":{"toolCallId":"call_1","toolName":"bash","arguments":{"command":"invalid"}},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        {"type":"tool.execution_complete","data":{"toolCallId":"call_1","success":false,"error":{"message":"Command not found"}},"id":"2","timestamp":"2026-01-01T12:00:02Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 1)

        if case .toolCall(let toolItem) = items[0].type {
            XCTAssertEqual(toolItem.status, .error("Command not found"))
        } else {
            XCTFail("Expected tool call")
        }
    }

    func testParseMultipleEvents() async throws {
        let eventsContent = """
        {"type":"user.message","data":{"content":"List files"},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        {"type":"assistant.message","data":{"content":"I'll run ls for you"},"id":"2","timestamp":"2026-01-01T12:00:02Z"}
        {"type":"assistant.message","data":{"content":"Here are the files: file1"},"id":"5","timestamp":"2026-01-01T12:00:05Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertGreaterThanOrEqual(items.count, 2)

        if case .user(let content) = items[0].type {
            XCTAssertEqual(content, "List files")
        }

        if case .assistant(let content) = items[1].type {
            XCTAssertEqual(content, "I'll run ls for you")
        }
    }

    func testParseMalformedJSON() async throws {
        let eventsContent = """
        {"type":"user.message","data":{"content":"Valid"},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        not valid json
        {"type":"assistant.message","data":{"content":"Also valid"},"id":"2","timestamp":"2026-01-01T12:00:02Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 2)
    }

    func testParseEmptyFile() async throws {
        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try "".write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertTrue(items.isEmpty)
    }

    func testParseNonExistentFile() async throws {
        let items = await parser.parseFullFile(at: "/non/existent/file.jsonl")

        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - Test parseEventsFile (Incremental)

    func testParseEventsFileIncremental() async throws {
        let eventsContent = """
        {"type":"user.message","data":{"content":"First"},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let result1 = await parser.parseEventsFile(at: eventsFile.path)
        XCTAssertEqual(result1.items.count, 1)

        let additionalContent = """
        {"type":"assistant.message","data":{"content":"Second"},"id":"2","timestamp":"2026-01-01T12:00:02Z"}
        """

        let handle = try FileHandle(forWritingTo: eventsFile)
        handle.seekToEndOfFile()
        if let data = additionalContent.data(using: .utf8) {
            handle.write(data)
        }
        try handle.close()

        let result2 = await parser.parseEventsFile(at: eventsFile.path)
        XCTAssertEqual(result2.items.count, 1)
    }

    // MARK: - Test edge cases

    func testParseEmptyContent() async throws {
        let eventsContent = """

        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertTrue(items.isEmpty)
    }

    func testParseUnknownEventType() async throws {
        let eventsContent = """
        {"type":"unknown.event","data":{"key":"value"},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertTrue(items.isEmpty)
    }

    func testParseMissingRequiredFields() async throws {
        let eventsContent = """
        {"type":"user.message","id":"1","timestamp":"2026-01-01T12:00:01Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertTrue(items.isEmpty)
    }

    func testParseToolWithDetailedResult() async throws {
        let eventsContent = """
        {"type":"tool.execution_start","data":{"toolCallId":"call_1","toolName":"view","arguments":{"path":"/test/file.swift"}},"id":"1","timestamp":"2026-01-01T12:00:01Z"}
        {"type":"tool.execution_complete","data":{"toolCallId":"call_1","success":true,"result":{"content":"file content","detailedContent":"full file content"}},"id":"2","timestamp":"2026-01-01T12:00:02Z"}
        """

        let eventsFile = tempDirectory.appendingPathComponent("events.jsonl")
        try eventsContent.write(to: eventsFile, atomically: true, encoding: .utf8)

        let items = await parser.parseFullFile(at: eventsFile.path)

        XCTAssertEqual(items.count, 1)

        if case .toolCall(let toolItem) = items[0].type {
            XCTAssertEqual(toolItem.result, "file content")
        } else {
            XCTFail("Expected tool call")
        }
    }
}
