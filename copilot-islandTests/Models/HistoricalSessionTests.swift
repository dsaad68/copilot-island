//
//  HistoricalSessionTests.swift
//  copilot-islandTests
//
//  Tests for HistoricalSession model
//

import XCTest
@testable import copilot_island

final class HistoricalSessionTests: XCTestCase {

    // MARK: - Test displayTitle

    func testDisplayTitleReturnsSummaryWhenAvailable() {
        let session = HistoricalSession(
            id: "test-id",
            summary: "My Test Session",
            cwd: "/Users/test/project",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        XCTAssertEqual(session.displayTitle, "My Test Session")
    }

    func testDisplayTitleReturnsSummaryWhenEmpty() {
        let session = HistoricalSession(
            id: "test-id",
            summary: "",
            cwd: "/Users/test/project",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        XCTAssertEqual(session.displayTitle, "project")
    }

    func testDisplayTitleReturnsSummaryWhenNil() {
        let session = HistoricalSession(
            id: "test-id",
            summary: nil,
            cwd: "/Users/test/my-cool-project",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        XCTAssertEqual(session.displayTitle, "my-cool-project")
    }

    func testDisplayTitleReturnsLastPathComponent() {
        let session = HistoricalSession(
            id: "test-id",
            summary: nil,
            cwd: "/Users/test/project/src/main",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        XCTAssertEqual(session.displayTitle, "main")
    }

    // MARK: - Test Equatable

    func testEquatableSameId() {
        let session1 = HistoricalSession(
            id: "test-id",
            summary: "Session 1",
            cwd: "/test/path1",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        let session2 = HistoricalSession(
            id: "test-id",
            summary: "Different Summary",
            cwd: "/test/path2",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        XCTAssertEqual(session1, session2)
    }

    func testEquatableDifferentId() {
        let session1 = HistoricalSession(
            id: "test-id-1",
            summary: "Session 1",
            cwd: "/test/path1",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        let session2 = HistoricalSession(
            id: "test-id-2",
            summary: "Session 1",
            cwd: "/test/path1",
            repository: nil,
            branch: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastMessage: nil
        )

        XCTAssertNotEqual(session1, session2)
    }

    // MARK: - Test YAML Parsing

    func testParseYamlValidFields() {
        let yaml = """
        id: test-id
        cwd: /Users/test/project
        git_root: /Users/test
        repository: testuser/testrepo
        branch: main
        summary: Test Session
        created_at: 2026-01-01T12:00:00.000Z
        updated_at: 2026-01-01T12:30:00.000Z
        """

        let result = parseYaml(yaml)

        XCTAssertEqual(result["id"], "test-id")
        XCTAssertEqual(result["cwd"], "/Users/test/project")
        XCTAssertEqual(result["git_root"], "/Users/test")
        XCTAssertEqual(result["repository"], "testuser/testrepo")
        XCTAssertEqual(result["branch"], "main")
        XCTAssertEqual(result["summary"], "Test Session")
        XCTAssertEqual(result["created_at"], "2026-01-01T12:00:00.000Z")
        XCTAssertEqual(result["updated_at"], "2026-01-01T12:30:00.000Z")
    }

    func testParseYamlWithQuotedValues() {
        let yaml = """
        summary: "My Summary"
        branch: 'main'
        """

        let result = parseYaml(yaml)

        XCTAssertEqual(result["summary"], "My Summary")
        XCTAssertEqual(result["branch"], "main")
    }

    func testParseYamlEmptyValue() {
        let yaml = """
        summary:
        cwd: /test
        """

        let result = parseYaml(yaml)

        XCTAssertEqual(result["summary"], "")
        XCTAssertEqual(result["cwd"], "/test")
    }

    func testParseYamlIgnoresComments() {
        let yaml = """
        # This is a comment
        cwd: /test
        """

        let result = parseYaml(yaml)

        XCTAssertEqual(result["cwd"], "/test")
        XCTAssertNil(result["# This is a comment"])
    }

    func testParseYamlMultipleKeys() {
        let yaml = """
        key1: value1
        key2: value2
        key3: value3
        """

        let result = parseYaml(yaml)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result["key1"], "value1")
        XCTAssertEqual(result["key2"], "value2")
        XCTAssertEqual(result["key3"], "value3")
    }

    // MARK: - Helper

    private func parseYaml(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
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
}
