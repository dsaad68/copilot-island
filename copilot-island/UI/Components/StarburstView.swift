//
//  StarburstView.swift
//  CopilotIsland
//
//  Minimal 4-point starburst for processing state – logo gradient, gentle rotation
//

import SwiftUI

struct StarburstView: View {
    var size: CGFloat = 12
    @State private var rotation: Double = 0

    private let rayLengthRatio: CGFloat = 0.4

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let r = min(canvasSize.width, canvasSize.height) * rayLengthRatio / 2
            var path = Path()
            for i in 0..<4 {
                let angle = Double(i) * 90 * .pi / 180
                let x = center.x + CGFloat(cos(angle)) * r
                let y = center.y + CGFloat(sin(angle)) * r
                path.move(to: center)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.logoPurple, .logoCyan]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
