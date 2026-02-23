//
//  SessionStore.swift
//  CopilotIsland
//
//  Manages session state and processes events from Copilot CLI
//

import Foundation
import Combine

enum SetupPhase: Equatable {
    case notStarted
    case checkingCopilot
    case checkingPlugin
    case done
}

@MainActor
class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var phase: SessionPhase = .idle
    @Published var currentToolName: String?
    @Published var sessionActive: Bool = false
    @Published var lastPrompt: String?
    @Published var cwd: String?
    @Published var modelName: String?
    @Published var currentSessionId: String?

    @Published var copilotInstalled: Bool = false
    @Published var pluginInstalled: Bool = false
    @Published var setupPhase: SetupPhase = .notStarted
    @Published var recentSessions: [HistoricalSession] = []

    @Published var pendingApproval: PendingToolApproval?
    @Published var sessionsWithNewMessages: Set<String> = []

    /// True while an assistant turn is in progress (between turn_start and turn_end)
    private var turnActive: Bool = false

    /// Fires on every event so views can react without @Published re-render cascade
    let eventReceived = PassthroughSubject<Void, Never>()

    /// When set, auto-approve incoming tool requests until this date
    var autoApproveUntil: Date?

    private var idleTimer: Timer?
    private let idleTimeoutSeconds: TimeInterval = 4.0
    private var socketServer: SocketServer?
    private var sessionWatcher: SessionWatcher?

    private init() {
        startSessionWatcher()
        checkSetup()
    }

    // MARK: - Session Watcher

    private func startSessionWatcher() {
        let watcher = SessionWatcher()

        watcher.onSessionStart = { [weak self] cwd, sessionId in
            guard let self else { return }
            self.sessionActive = true
            self.cwd = cwd
            self.currentSessionId = sessionId
            if !self.copilotInstalled {
                self.copilotInstalled = true
            }
            self.loadRecentSessions()
            self.eventReceived.send()
        }

        watcher.onSessionEnd = { [weak self] in
            guard let self else { return }
            self.sessionActive = false
            self.phase = .ended(reason: "complete")
            self.cancelIdleTimer()
            self.loadRecentSessions()
            self.eventReceived.send()
        }

        watcher.onPhaseChange = { [weak self] newPhase in
            guard let self else { return }
            // During an active turn, don't let sub-events (tool complete → .processing)
            // override with idle timer — the turn manages phase directly.
            if self.turnActive {
                // Still update phase for tool-level detail, but don't start idle timer
                self.phase = newPhase
            } else {
                self.phase = newPhase
                if case .idle = newPhase {
                    self.cancelIdleTimer()
                } else {
                    self.resetIdleTimer()
                }
            }
            self.eventReceived.send()
        }

        watcher.onPrompt = { [weak self] prompt in
            guard let self else { return }
            self.lastPrompt = prompt
        }

        watcher.onModelChange = { [weak self] model in
            guard let self else { return }
            self.modelName = model
        }

        watcher.onTurnStart = { [weak self] in
            guard let self else { return }
            self.turnActive = true
            self.phase = .processing
            self.cancelIdleTimer()
        }

        watcher.onTurnEnd = { [weak self] in
            guard let self else { return }
            self.turnActive = false
            let replaying = self.sessionWatcher?.isReplaying ?? false
            if !replaying, let sid = self.currentSessionId {
                self.sessionsWithNewMessages.insert(sid)
            }
            self.phase = .idle
            self.cancelIdleTimer()
        }

        sessionWatcher = watcher
        watcher.start()
    }

    // MARK: - Setup

    func checkSetup() {
        loadRecentSessions()
        setupPhase = .checkingCopilot

        Task {
            let copilotPath = await Task.detached { PluginInstaller.copilotPath }.value
            self.copilotInstalled = copilotPath != nil
            self.setupPhase = .checkingPlugin

            try? await Task.sleep(nanoseconds: 400_000_000)

            let pluginOk: Bool
            if copilotPath != nil {
                pluginOk = await Task.detached { PluginInstaller.isInstalled }.value
            } else {
                pluginOk = false
            }
            self.pluginInstalled = pluginOk

            try? await Task.sleep(nanoseconds: 400_000_000)

            self.setupPhase = .done
        }
    }

    func installPlugin() {
        Task {
            let success = await Task.detached { PluginInstaller.install() }.value
            self.pluginInstalled = success
        }
    }

    func updatePlugin() {
        Task {
            let success = await Task.detached { PluginInstaller.update() }.value
            if success { self.pluginInstalled = true }
        }
    }

    func loadRecentSessions() {
        recentSessions = HistoricalSession.loadRecent()
    }

    // MARK: - Socket Server (approval only)

    func startServer() {
        socketServer = SocketServer(
            eventHandler: { [weak self] event in
                self?.processSocketEvent(event)
            },
            approvalHandler: { [weak self] approval in
                self?.handleApprovalRequest(approval)
            }
        )
        do {
            try socketServer?.start()
        } catch {
            print("Failed to start socket server: \(error)")
        }
    }

    /// Socket events — only preToolUse and sessionEnd are meaningful now.
    /// All other state is driven by SessionWatcher via events.jsonl.
    private func processSocketEvent(_ event: CopilotEvent) {
        switch event.event {
        case .preToolUse:
            currentToolName = event.toolName
            phase = .runningTool(name: event.toolName ?? "tool")
            resetIdleTimer()

        case .sessionEnd:
            sessionActive = false
            phase = .ended(reason: event.reason ?? "complete")
            cancelIdleTimer()
            loadRecentSessions()
        }

        // Activate session on any socket event if not already active
        if !sessionActive && event.event != .sessionEnd {
            sessionActive = true
            cwd = event.cwd
            if !copilotInstalled || !pluginInstalled {
                copilotInstalled = true
                pluginInstalled = true
            }
            loadRecentSessions()
        }

        eventReceived.send()
    }

    // MARK: - Tool Approval

    private func handleApprovalRequest(_ approval: PendingToolApproval) {
        if let until = autoApproveUntil, Date() < until {
            socketServer?.respondToPermission(requestId: approval.requestId, allow: true)
            phase = .runningTool(name: approval.toolName)
            resetIdleTimer()
            return
        }
        pendingApproval = approval
        phase = .waitingForApproval(toolName: approval.toolName)
        cancelIdleTimer()
        eventReceived.send()
    }

    func approveToolUse() {
        guard let approval = pendingApproval else { return }
        socketServer?.respondToPermission(requestId: approval.requestId, allow: true)
        pendingApproval = nil
        phase = .runningTool(name: approval.toolName)
        resetIdleTimer()
        eventReceived.send()
    }

    func denyToolUse() {
        guard let approval = pendingApproval else { return }
        socketServer?.respondToPermission(requestId: approval.requestId, allow: false)
        pendingApproval = nil
        phase = .processing
        resetIdleTimer()
        eventReceived.send()
    }

    // MARK: - Idle Timer

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeoutSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if case .processing = self.phase {
                    self.phase = .idle
                }
                if case .runningTool = self.phase {
                    self.phase = .idle
                }
            }
        }
    }

    private func cancelIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
}
