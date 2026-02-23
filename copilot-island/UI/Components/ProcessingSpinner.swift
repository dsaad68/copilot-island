//
//  ProcessingSpinner.swift
//  CopilotIsland
//
//  Animated spinner for processing state – logo gradient arc
//

import SwiftUI

struct ProcessingSpinner: View {
    @State private var rotation: Double = 0

    private let strokeStyle = StrokeStyle(lineWidth: 2, lineCap: .round)
    private let size: CGFloat = 12

    var body: some View {
        ZStack {
            // Subtle glow layer
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    Color.logoPurpleLight.opacity(0.4),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .blur(radius: 1)

            // Main gradient arc (purple → cyan)
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.logoAngularGradient, style: strokeStyle)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
