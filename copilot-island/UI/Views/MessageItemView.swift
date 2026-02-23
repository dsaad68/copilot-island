//
//  MessageItemView.swift
//  CopilotIsland
//
//  Renders a single chat history item based on its type
//

import SwiftUI
import MarkdownUI

struct MessageItemView: View {
    let item: ChatHistoryItem

    var body: some View {
        switch item.type {
        case .user(let content):
            UserMessageView(content: content)
        case .assistant(let content):
            AssistantMessageView(content: content)
        case .toolCall(let tool):
            ToolCallView(tool: tool)
        case .thinking(let content):
            ThinkingView(content: content)
        }
    }
}

struct ThinkingView: View {
    let content: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)

                    Text("Reasoning")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Markdown(content)
                    .markdownTextStyle {
                        FontSize(11)
                        ForegroundColor(.white.opacity(0.6))
                    }
                    .italic()
                    .padding(.leading, 26)
            }
        }
    }
}
