//
//  UserMessageView.swift
//  CopilotIsland
//
//  Displays a user message in chat history (right-aligned)
//

import SwiftUI

struct UserMessageView: View {
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 40)
            
            Text(content)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(10)
                .textSelection(.enabled)
        }
    }
}
