//
//  ToolCallItemTests.swift
//  copilot-islandTests
//
//  Tests for ToolCallItem model
//

import XCTest
@testable import copilot_island

final class ToolCallItemTests: XCTestCase {

    // MARK: - Test statusDisplay

    func testStatusDisplayRunning() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .running,
            result: nil
        )

        XCTAssertEqual(item.statusDisplay, "Running")
    }

    func testStatusDisplaySuccess() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .success,
            result: "output"
        )

        XCTAssertEqual(item.statusDisplay, "Success")
    }

    func testStatusDisplayErrorWithMessage() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .error("Command failed"),
            result: nil
        )

        XCTAssertEqual(item.statusDisplay, "Command failed")
    }

    func testStatusDisplayErrorWithoutMessage() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .error(nil),
            result: nil
        )

        XCTAssertEqual(item.statusDisplay, "Error")
    }

    // MARK: - Test inputPreview

    func testInputPreviewEmpty() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .running,
            result: nil
        )

        XCTAssertEqual(item.inputPreview, "")
    }

    func testInputPreviewThreeOrFewerKeys() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: ["command": "ls", "verbose": "true", "color": "never"],
            status: .running,
            result: nil
        )

        let preview = item.inputPreview
        XCTAssertTrue(preview.contains("command: ls"))
        XCTAssertTrue(preview.contains("verbose: true"))
        XCTAssertTrue(preview.contains("color: never"))
        XCTAssertFalse(preview.contains("..."))
    }

    func testInputPreviewMoreThanThreeKeys() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [
                "arg1": "value1",
                "arg2": "value2",
                "arg3": "value3",
                "arg4": "value4",
                "arg5": "value5"
            ],
            status: .running,
            result: nil
        )

        let preview = item.inputPreview
        XCTAssertTrue(preview.hasSuffix("..."))
    }

    func testInputPreviewSortedKeys() {
        let item = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: ["zebra": "z", "apple": "a", "mango": "m"],
            status: .running,
            result: nil
        )

        let preview = item.inputPreview
        XCTAssertTrue(preview.hasPrefix("apple: a"))
    }

    // MARK: - Test Equatable

    func testEquatableSameAllFields() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: ["command": "ls"],
            status: .success,
            result: "output"
        )

        let item2 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: ["command": "ls"],
            status: .success,
            result: "output"
        )

        XCTAssertEqual(item1, item2)
    }

    func testEquatableDifferentId() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .running,
            result: nil
        )

        let item2 = ToolCallItem(
            id: "tool-2",
            name: "bash",
            input: [:],
            status: .running,
            result: nil
        )

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableDifferentName() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .running,
            result: nil
        )

        let item2 = ToolCallItem(
            id: "tool-1",
            name: "git",
            input: [:],
            status: .running,
            result: nil
        )

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableDifferentInput() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: ["command": "ls"],
            status: .running,
            result: nil
        )

        let item2 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: ["command": "cat"],
            status: .running,
            result: nil
        )

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableDifferentStatus() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .running,
            result: nil
        )

        let item2 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .success,
            result: nil
        )

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableDifferentResult() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .success,
            result: "output1"
        )

        let item2 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .success,
            result: "output2"
        )

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatableNilVsEmptyResult() {
        let item1 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .success,
            result: nil
        )

        let item2 = ToolCallItem(
            id: "tool-1",
            name: "bash",
            input: [:],
            status: .success,
            result: ""
        )

        XCTAssertNotEqual(item1, item2)
    }
}
