//
//  SessionStoreIntegrationTests.swift
//  copilot-islandTests
//
//  Integration tests for SessionStore
//

import XCTest
import Combine
@testable import copilot_island

@MainActor
final class SessionStoreIntegrationTests: XCTestCase {

    var sessionStore: SessionStore!
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        sessionStore = SessionStore.shared
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Test Phase Transitions

    func testPhaseTransitionFromIdleToProcessing() {
        let expectation = XCTestExpectation(description: "Phase changes to processing")

        sessionStore.$phase
            .dropFirst()
            .first()
            .sink { phase in
                if phase.isProcessing {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sessionStore.phase = .processing

        wait(for: [expectation], timeout: 1.0)
    }

    func testPhaseTransitionToRunningTool() {
        let expectation = XCTestExpectation(description: "Phase changes to runningTool")

        sessionStore.$phase
            .dropFirst()
            .first()
            .sink { phase in
                if phase.isRunningTool {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sessionStore.phase = .runningTool(name: "bash")

        wait(for: [expectation], timeout: 1.0)
    }

    func testPhaseTransitionToError() {
        let expectation = XCTestExpectation(description: "Phase changes to error")

        sessionStore.$phase
            .dropFirst()
            .first()
            .sink { phase in
                if phase.isError {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sessionStore.phase = .error(message: "Test error")

        wait(for: [expectation], timeout: 1.0)
    }

    func testPhaseTransitionToEnded() {
        let expectation = XCTestExpectation(description: "Phase changes to ended")

        sessionStore.$phase
            .dropFirst()
            .first()
            .sink { phase in
                if phase.isEnded {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sessionStore.phase = .ended(reason: "complete")

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Test Session State

    func testSessionActiveState() {
        sessionStore.sessionActive = true
        XCTAssertTrue(sessionStore.sessionActive)

        sessionStore.sessionActive = false
        XCTAssertFalse(sessionStore.sessionActive)
    }

    func testCurrentSessionId() {
        let testSessionId = "test-session-123"
        sessionStore.currentSessionId = testSessionId

        XCTAssertEqual(sessionStore.currentSessionId, testSessionId)
    }

    func testCwdTracking() {
        let testCwd = "/Users/test/project"
        sessionStore.cwd = testCwd

        XCTAssertEqual(sessionStore.cwd, testCwd)
    }

    func testLastPromptTracking() {
        let testPrompt = "Explain this code"
        sessionStore.lastPrompt = testPrompt

        XCTAssertEqual(sessionStore.lastPrompt, testPrompt)
    }

    func testModelNameTracking() {
        let testModel = "claude-3-opus"
        sessionStore.modelName = testModel

        XCTAssertEqual(sessionStore.modelName, testModel)
    }

    // MARK: - Test Event Received Publisher

    func testEventReceivedPublisher() {
        let expectation = XCTestExpectation(description: "Event received")

        sessionStore.eventReceived
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sessionStore.eventReceived.send()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Test Setup Phase

    func testSetupPhaseTransitions() {
        sessionStore.setupPhase = .checkingCopilot
        XCTAssertEqual(sessionStore.setupPhase, .checkingCopilot)

        sessionStore.setupPhase = .checkingPlugin
        XCTAssertEqual(sessionStore.setupPhase, .checkingPlugin)

        sessionStore.setupPhase = .done
        XCTAssertEqual(sessionStore.setupPhase, .done)

        sessionStore.setupPhase = .notStarted
        XCTAssertEqual(sessionStore.setupPhase, .notStarted)
    }

    // MARK: - Test Installation State

    func testCopilotInstalledState() {
        sessionStore.copilotInstalled = true
        XCTAssertTrue(sessionStore.copilotInstalled)

        sessionStore.copilotInstalled = false
        XCTAssertFalse(sessionStore.copilotInstalled)
    }

    func testPluginInstalledState() {
        sessionStore.pluginInstalled = true
        XCTAssertTrue(sessionStore.pluginInstalled)

        sessionStore.pluginInstalled = false
        XCTAssertFalse(sessionStore.pluginInstalled)
    }

    // MARK: - Test Recent Sessions

    func testRecentSessionsArray() {
        let testSessions: [HistoricalSession] = []
        sessionStore.recentSessions = testSessions

        XCTAssertEqual(sessionStore.recentSessions.count, 0)
    }

    // MARK: - Test Pending Approval

    func testPendingApprovalState() {
        let approval = PendingToolApproval(requestId: "req-123", toolName: "bash", toolArgs: nil, cwd: "/test")
        sessionStore.pendingApproval = approval

        XCTAssertNotNil(sessionStore.pendingApproval)
        XCTAssertEqual(sessionStore.pendingApproval?.toolName, "bash")

        sessionStore.pendingApproval = nil

        XCTAssertNil(sessionStore.pendingApproval)
    }

    // MARK: - Test Sessions With New Messages

    func testSessionsWithNewMessages() {
        let sessionId1 = "session-1"
        let sessionId2 = "session-2"

        sessionStore.sessionsWithNewMessages.insert(sessionId1)
        sessionStore.sessionsWithNewMessages.insert(sessionId2)

        XCTAssertTrue(sessionStore.sessionsWithNewMessages.contains(sessionId1))
        XCTAssertTrue(sessionStore.sessionsWithNewMessages.contains(sessionId2))
        XCTAssertEqual(sessionStore.sessionsWithNewMessages.count, 2)

        sessionStore.sessionsWithNewMessages.remove(sessionId1)

        XCTAssertFalse(sessionStore.sessionsWithNewMessages.contains(sessionId1))
        XCTAssertTrue(sessionStore.sessionsWithNewMessages.contains(sessionId2))
    }

    // MARK: - Test Auto Approve

    func testAutoApproveUntil() {
        let futureDate = Date().addingTimeInterval(60)
        sessionStore.autoApproveUntil = futureDate

        XCTAssertNotNil(sessionStore.autoApproveUntil)

        sessionStore.autoApproveUntil = nil

        XCTAssertNil(sessionStore.autoApproveUntil)
    }

    // MARK: - Test Full Flow Simulation

    func testFullSessionFlowSimulation() {
        sessionStore.sessionActive = true
        sessionStore.cwd = "/test/project"
        sessionStore.currentSessionId = "flow-test-session"

        XCTAssertTrue(sessionStore.sessionActive)
        XCTAssertEqual(sessionStore.cwd, "/test/project")
        XCTAssertEqual(sessionStore.currentSessionId, "flow-test-session")

        sessionStore.lastPrompt = "Hello Copilot"
        XCTAssertEqual(sessionStore.lastPrompt, "Hello Copilot")

        sessionStore.phase = .processing
        XCTAssertTrue(sessionStore.phase.isProcessing)

        sessionStore.phase = .runningTool(name: "bash")
        XCTAssertTrue(sessionStore.phase.isRunningTool)

        sessionStore.phase = .idle
        XCTAssertTrue(sessionStore.phase.isIdle)

        sessionStore.sessionActive = false
        sessionStore.phase = .ended(reason: "complete")
        XCTAssertTrue(sessionStore.phase.isEnded)
    }
}
