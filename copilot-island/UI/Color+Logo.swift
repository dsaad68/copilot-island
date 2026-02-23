//
//  Color+Logo.swift
//  CopilotIsland
//
//  Logo palette: purple → cyan gradient and accent colors
//

import SwiftUI

extension Color {
    /// Primary purple (#6E40C9) – GitHub Copilot / logo base
    static let logoPurple = Color(red: 0.43, green: 0.25, blue: 0.79)

    /// Soft purple (#A78BFA) – gradients, glows
    static let logoPurpleLight = Color(red: 0.65, green: 0.55, blue: 0.98)

    /// Cyan accent (#22D3EE) – tech / starburst highlight
    static let logoCyan = Color(red: 0.13, green: 0.83, blue: 0.93)

    /// Linear gradient purple → cyan (start = leading/top, end = trailing/bottom)
    static var logoGradient: LinearGradient {
        LinearGradient(
            colors: [.logoPurple, .logoPurpleLight, .logoCyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Angular gradient for circular strokes (e.g. spinner arc)
    static var logoAngularGradient: AngularGradient {
        AngularGradient(
            colors: [.logoPurple, .logoPurpleLight, .logoCyan, .logoPurpleLight, .logoPurple],
            center: .center
        )
    }
}
