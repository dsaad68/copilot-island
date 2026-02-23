//
//  ChatView.swift
//  CopilotIsland
//
//  Displays chat history for a session
//

import SwiftUI
import Combine

struct ChatView: View {
    let session: HistoricalSession
    @ObservedObject var sessionStore: SessionStore
    let onBack: () -> Void

    @State private var history: [ChatHistoryItem] = []
    @State private var isLoading = true
    @State private var isHeaderHovered = false

    private let parser = ConversationParser()
    private let chatPollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chatHeader
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if history.isEmpty {
                Text("No messages")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messageList
            }
        }
        .task {
            await loadHistory()
        }
        .onReceive(sessionStore.eventReceived) { _ in
            Task { await reloadHistory() }
        }
        .onReceive(chatPollTimer) { _ in
            guard sessionStore.sessionActive else { return }
            Task { await reloadHistory() }
        }
    }

    @ViewBuilder
    private var chatHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(isHeaderHovered ? 1.0 : 0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(isHeaderHovered ? 0.08 : 0))
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHeaderHovered = hovering
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text((session.cwd as NSString).lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Color.clear
                        .frame(height: 0)
                        .id("bottom")

                    ForEach(history.reversed()) { item in
                        MessageItemView(item: item)
                            .scaleEffect(x: 1, y: -1)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .scaleEffect(x: 1, y: -1)
            .onChange(of: history.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var eventsPath: String {
        HistoricalSession.sessionStateDir
            .appendingPathComponent(session.id)
            .appendingPathComponent("events.jsonl").path
    }

    private func loadHistory() async {
        let items = await parser.parseFullFile(at: eventsPath)
        await MainActor.run {
            history = items
            isLoading = false
        }
    }

    private func reloadHistory() async {
        let items = await parser.parseFullFile(at: eventsPath)
        await MainActor.run {
            history = items
        }
    }
}
