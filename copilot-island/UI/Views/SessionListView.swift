//
//  SessionListView.swift
//  CopilotIsland
//
//  Shows the current Copilot session status, setup flow, and session history
//

import SwiftUI
import Combine

struct SessionListView: View {
    @ObservedObject var sessionStore: SessionStore
    var onSelectSession: (HistoricalSession) -> Void
    @State private var isInstallingPlugin = false
    private let sessionPollTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text("Copilot")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                statusBadge
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Show setup checklist during checking, or when Copilot CLI is missing
            if sessionStore.setupPhase != .done || !sessionStore.copilotInstalled {
                setupChecklist
            } else {
                // Plugin is optional — show soft recommendation if not installed
                if !sessionStore.pluginInstalled {
                    pluginRecommendation

                    Divider().background(Color.white.opacity(0.1))
                }

                if sessionStore.sessionActive {
                    sessionInfo
                }

                if !sessionStore.recentSessions.isEmpty {
                    if sessionStore.sessionActive {
                        Divider().background(Color.white.opacity(0.1))
                    }
                    recentSessionsList
                } else if !sessionStore.sessionActive {
                    Text("No sessions yet")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 8)
        .onReceive(sessionStore.eventReceived) { _ in
            sessionStore.loadRecentSessions()
        }
        .onReceive(sessionPollTimer) { _ in
            guard sessionStore.sessionActive else { return }
            sessionStore.loadRecentSessions()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text) = statusInfo

        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private var statusInfo: (Color, String) {
        // Show checking status during setup
        if !sessionStore.sessionActive {
            switch sessionStore.setupPhase {
            case .notStarted, .checkingCopilot, .checkingPlugin:
                return (.orange, "Checking...")
            case .done:
                if !sessionStore.copilotInstalled {
                    return (.orange, "Setup Required")
                }
                if !sessionStore.pluginInstalled {
                    return (.orange, "Plugin Missing")
                }
            }
        }
        switch sessionStore.phase {
        case .idle:
            return (.green, "Ready")
        case .processing:
            return (.blue, "Processing")
        case .runningTool(let name):
            return (.purple, name)
        case .waitingForApproval(let toolName):
            return (.orange, "Approve \(toolName)?")
        case .error(let message):
            return (.red, message)
        case .ended:
            return (.green, "Ready")
        }
    }

    // MARK: - Setup Checklist

    private enum CheckItemState {
        case waiting
        case checking
        case result(installed: Bool)
    }

    private var copilotCheckState: CheckItemState {
        switch sessionStore.setupPhase {
        case .notStarted:
            return .waiting
        case .checkingCopilot:
            return .checking
        case .checkingPlugin, .done:
            return .result(installed: sessionStore.copilotInstalled)
        }
    }

    @ViewBuilder
    private var setupChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            checklistItem(label: "Copilot CLI", state: copilotCheckState)
        }
    }

    private func checklistItem(label: String, state: CheckItemState) -> some View {
        HStack(spacing: 6) {
            Group {
                switch state {
                case .waiting:
                    Image(systemName: "circle")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                case .checking:
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 11, height: 11)
                case .result(let installed):
                    Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(installed ? .green : .red)
                }
            }

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Group {
                switch state {
                case .waiting:
                    Text("Waiting...")
                        .foregroundColor(.white.opacity(0.3))
                case .checking:
                    Text("Checking...")
                        .foregroundColor(.orange.opacity(0.8))
                case .result(let installed):
                    Text(installed ? "Installed" : "Missing")
                        .foregroundColor(installed ? .green.opacity(0.7) : .red.opacity(0.7))
                }
            }
            .font(.system(size: 10))
        }
        .animation(.easeInOut(duration: 0.3), value: sessionStore.setupPhase == .done)
    }

    // MARK: - Plugin Recommendation

    @ViewBuilder
    private var pluginRecommendation: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.8))

                Text("Plugin recommended for tool approval")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

            if sessionStore.copilotInstalled {
                Button(action: {
                    isInstallingPlugin = true
                    sessionStore.installPlugin()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isInstallingPlugin = false
                    }
                }) {
                    HStack(spacing: 6) {
                        if isInstallingPlugin {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 11))
                        }
                        Text("Install Plugin")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isInstallingPlugin)
            }
        }
    }

    // MARK: - Active Session Info

    @ViewBuilder
    private var sessionInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cwd = sessionStore.cwd {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))

                    Text(cwd)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let model = sessionStore.modelName {
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))

                    Text(model)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if let tool = sessionStore.currentToolName {
                HStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Running: \(tool)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if let prompt = sessionStore.lastPrompt {
                HStack(alignment: .top) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))

                    Text(prompt)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Recent Sessions

    @ViewBuilder
    private var recentSessionsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sessionStore.recentSessions) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private func sessionRow(_ session: HistoricalSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)

                if sessionStore.sessionsWithNewMessages.contains(session.id) {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                }

                Spacer()

                Text(relativeTime(session.updatedAt))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            if let message = session.lastMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            sessionStore.sessionsWithNewMessages.remove(session.id)
            onSelectSession(session)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
