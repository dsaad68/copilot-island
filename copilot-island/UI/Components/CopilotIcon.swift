//
//  CopilotIcon.swift
//  CopilotIsland
//
//  App logo used in notch and headers – breathing animation when active
//

import SwiftUI

struct CopilotIcon: View {
    let size: CGFloat
    var animate: Bool = false

    /// 0 = dim/small, 1 = full – driven by repeatForever breathing animation
    @State private var breath: Double = 0

    init(size: CGFloat = 16, animate: Bool = false) {
        self.size = size
        self.animate = animate
    }

    private var opacity: Double {
        animate ? (0.75 + 0.25 * breath) : 1.0
    }

    private var scale: Double {
        animate ? (0.97 + 0.03 * breath) : 1.0
    }

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(opacity)
            .scaleEffect(scale)
            .animation(animate ? .easeInOut(duration: 1.25) : .default, value: breath)
            .onAppear {
                if animate {
                    withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                        breath = 1
                    }
                }
            }
    }
}
