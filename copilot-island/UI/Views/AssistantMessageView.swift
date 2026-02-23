//
//  AssistantMessageView.swift
//  CopilotIsland
//
//  Displays an assistant message in chat history (left-aligned)
//

import SwiftUI
import MarkdownUI

struct AssistantMessageView: View {
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.purple.opacity(0.6))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Markdown(content)
                .markdownTextStyle {
                    FontSize(12)
                    ForegroundColor(.white.opacity(0.85))
                }
                .markdownBlockStyle(\.codeBlock) { configuration in
                    configuration.label
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .textSelection(.enabled)

            Spacer(minLength: 40)
        }
    }
}
