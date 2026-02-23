//
//  RobotIcon.swift
//  CopilotIsland
//
//  Simple robot logo (drawn, not emoji) for headers
//

import SwiftUI

struct RobotIcon: View {
    var size: CGFloat = 20
    var animate: Bool = false

    @State private var progress: Double = 0

    private var headW: CGFloat { size * 0.9 }
    private var headH: CGFloat { size * 0.75 }
    private var eyeR: CGFloat { size * 0.12 }
    private var antH: CGFloat { size * 0.2 }

    private var headGradient: LinearGradient {
        LinearGradient(
            colors: [Color.logoPurpleLight.opacity(0.95), Color.logoPurple],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var antennaGradient: LinearGradient {
        LinearGradient(
            colors: [Color.logoCyan.opacity(0.9), Color.logoPurpleLight],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Head with gradient and soft inner highlight
            RoundedRectangle(cornerRadius: size * 0.14)
                .fill(headGradient)
                .frame(width: headW, height: headH)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.logoPurpleLight.opacity(0.8), Color.logoPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(1, size * 0.05)
                        )
                )
                .shadow(color: Color.logoPurple.opacity(0.4), radius: size * 0.08)

            // Antenna with gradient
            Capsule()
                .fill(antennaGradient)
                .frame(width: size * 0.09, height: antH)
                .offset(y: -antH / 2 - headH / 2 + 2)

            // Antenna tip with glow (pulses when animate)
            ZStack {
                Circle()
                    .fill(Color.logoCyan)
                    .frame(width: size * 0.16, height: size * 0.16)
                    .shadow(
                        color: Color.logoCyan.opacity(animate ? (0.4 + 0.5 * progress) : 0.7),
                        radius: size * (animate ? (0.04 + 0.06 * progress) : 0.06)
                    )
                Circle()
                    .fill(Color.logoCyan.opacity(animate ? (0.7 + 0.25 * progress) : 0.9))
                    .frame(width: size * 0.12, height: size * 0.12)
            }
            .offset(y: -antH - headH / 2 + 2)

            // Eyes with subtle depth
            HStack(spacing: size * 0.22) {
                ForEach(0..<2, id: \.self) { _ in
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: eyeR * 2, height: eyeR * 2)
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: eyeR * 0.6, height: eyeR * 0.6)
                            .offset(x: -eyeR * 0.2, y: -eyeR * 0.2)
                    }
                }
            }
            .offset(y: -size * 0.06)

            // Mouth – subtle smile curve
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.28, height: max(1.2, size * 0.05))
                .offset(y: size * 0.2)
        }
        .scaleEffect(animate ? (0.97 + 0.06 * progress) : 1.0)
        .animation(animate ? .easeInOut(duration: 1.1) : .default, value: progress)
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    progress = 1
                }
            }
        }
        .onChange(of: animate) { _, isAnimating in
            if isAnimating {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    progress = 1
                }
            } else {
                progress = 0
            }
        }
        .frame(width: size, height: size)
    }
}
