//
//  SessionPhaseTests.swift
//  copilot-islandTests
//
//  Tests for SessionPhase enum
//

import XCTest
@testable import copilot_island

final class SessionPhaseTests: XCTestCase {

    // MARK: - Test Cases

    func testIdleCase() {
        let phase: SessionPhase = .idle
        XCTAssertTrue(phase.isIdle)
        XCTAssertFalse(phase.isProcessing)
        XCTAssertFalse(phase.isRunningTool)
        XCTAssertFalse(phase.isWaitingForApproval)
        XCTAssertFalse(phase.isError)
        XCTAssertFalse(phase.isEnded)
    }

    func testProcessingCase() {
        let phase: SessionPhase = .processing
        XCTAssertFalse(phase.isIdle)
        XCTAssertTrue(phase.isProcessing)
        XCTAssertFalse(phase.isRunningTool)
        XCTAssertFalse(phase.isWaitingForApproval)
        XCTAssertFalse(phase.isError)
        XCTAssertFalse(phase.isEnded)
    }

    func testRunningToolCase() {
        let phase: SessionPhase = .runningTool(name: "bash")
        XCTAssertFalse(phase.isIdle)
        XCTAssertFalse(phase.isProcessing)
        XCTAssertTrue(phase.isRunningTool)
        XCTAssertFalse(phase.isWaitingForApproval)
        XCTAssertFalse(phase.isError)
        XCTAssertFalse(phase.isEnded)
    }

    func testWaitingForApprovalCase() {
        let phase: SessionPhase = .waitingForApproval(toolName: "bash")
        XCTAssertFalse(phase.isIdle)
        XCTAssertFalse(phase.isProcessing)
        XCTAssertFalse(phase.isRunningTool)
        XCTAssertTrue(phase.isWaitingForApproval)
        XCTAssertFalse(phase.isError)
        XCTAssertFalse(phase.isEnded)
    }

    func testErrorCase() {
        let phase: SessionPhase = .error(message: "Something went wrong")
        XCTAssertFalse(phase.isIdle)
        XCTAssertFalse(phase.isProcessing)
        XCTAssertFalse(phase.isRunningTool)
        XCTAssertFalse(phase.isWaitingForApproval)
        XCTAssertTrue(phase.isError)
        XCTAssertFalse(phase.isEnded)
    }

    func testEndedCase() {
        let phase: SessionPhase = .ended(reason: "complete")
        XCTAssertFalse(phase.isIdle)
        XCTAssertFalse(phase.isProcessing)
        XCTAssertFalse(phase.isRunningTool)
        XCTAssertFalse(phase.isWaitingForApproval)
        XCTAssertFalse(phase.isError)
        XCTAssertTrue(phase.isEnded)
    }

    // MARK: - Test Display Names

    func testIdleDisplayName() {
        let phase: SessionPhase = .idle
        XCTAssertEqual(phase.displayName, "Ready")
    }

    func testProcessingDisplayName() {
        let phase: SessionPhase = .processing
        XCTAssertEqual(phase.displayName, "Processing...")
    }

    func testRunningToolDisplayName() {
        let phase: SessionPhase = .runningTool(name: "bash")
        XCTAssertEqual(phase.displayName, "Running bash")
    }

    func testWaitingForApprovalDisplayName() {
        let phase: SessionPhase = .waitingForApproval(toolName: "bash")
        XCTAssertEqual(phase.displayName, "Approve bash?")
    }

    func testErrorDisplayName() {
        let phase: SessionPhase = .error(message: "Connection failed")
        XCTAssertEqual(phase.displayName, "Error: Connection failed")
    }

    func testEndedDisplayName() {
        let phase: SessionPhase = .ended(reason: "user_cancelled")
        XCTAssertEqual(phase.displayName, "Ended (user_cancelled)")
    }

    // MARK: - Test Equatable

    func testEquatableIdle() {
        let phase1: SessionPhase = .idle
        let phase2: SessionPhase = .idle
        XCTAssertEqual(phase1, phase2)
    }

    func testEquatableProcessing() {
        let phase1: SessionPhase = .processing
        let phase2: SessionPhase = .processing
        XCTAssertEqual(phase1, phase2)
    }

    func testEquatableRunningToolSameName() {
        let phase1: SessionPhase = .runningTool(name: "bash")
        let phase2: SessionPhase = .runningTool(name: "bash")
        XCTAssertEqual(phase1, phase2)
    }

    func testEquatableRunningToolDifferentName() {
        let phase1: SessionPhase = .runningTool(name: "bash")
        let phase2: SessionPhase = .runningTool(name: "git")
        XCTAssertNotEqual(phase1, phase2)
    }

    func testEquatableErrorSameMessage() {
        let phase1: SessionPhase = .error(message: "Failed")
        let phase2: SessionPhase = .error(message: "Failed")
        XCTAssertEqual(phase1, phase2)
    }

    func testEquatableErrorDifferentMessage() {
        let phase1: SessionPhase = .error(message: "Failed")
        let phase2: SessionPhase = .error(message: "Success")
        XCTAssertNotEqual(phase1, phase2)
    }

    func testEquatableEndedSameReason() {
        let phase1: SessionPhase = .ended(reason: "complete")
        let phase2: SessionPhase = .ended(reason: "complete")
        XCTAssertEqual(phase1, phase2)
    }

    func testEquatableEndedDifferentReason() {
        let phase1: SessionPhase = .ended(reason: "complete")
        let phase2: SessionPhase = .ended(reason: "cancelled")
        XCTAssertNotEqual(phase1, phase2)
    }

    func testNotEqualBetweenDifferentCases() {
        let phases: [SessionPhase] = [
            .idle,
            .processing,
            .runningTool(name: "bash"),
            .waitingForApproval(toolName: "git"),
            .error(message: "Error"),
            .ended(reason: "done")
        ]

        for i in 0..<phases.count {
            for j in 0..<phases.count {
                if i != j {
                    XCTAssertNotEqual(phases[i], phases[j])
                }
            }
        }
    }
}
