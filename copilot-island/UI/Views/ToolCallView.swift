//
//  ToolCallView.swift
//  CopilotIsland
//
//  Displays a tool call in chat history
//

import SwiftUI

struct ToolCallView: View {
    let tool: ToolCallItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                statusIcon
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
                
                Text(tool.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text(tool.statusDisplay)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor.opacity(0.7))
            }
            
            if !tool.inputPreview.isEmpty {
                Text(tool.inputPreview)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            
            if let result = tool.result, !result.isEmpty {
                Text(result)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(3)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch tool.status {
        case .running:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        case .success:
            Image(systemName: "checkmark.circle.fill")
        case .error:
            Image(systemName: "xmark.circle.fill")
        }
    }
    
    private var statusColor: Color {
        switch tool.status {
        case .running: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
}
