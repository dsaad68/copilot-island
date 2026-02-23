//
//  NotchMenuView.swift
//  CopilotIsland
//
//  Settings and controls shown when the notch is opened
//

import SwiftUI

struct NotchMenuView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var sessionStore: SessionStore
    @State private var installFeedback: InstallFeedback?
    @State private var showConfirm: Bool = false

    private enum InstallFeedback {
        case success, failure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(icon: "chevron.left", label: "Back") {
                viewModel.toggleMenu()
            }

            Divider()
                .background(Color.white.opacity(0.1))

            if sessionStore.pluginInstalled {
                pluginStatusRow(installed: true)
            } else if let feedback = installFeedback {
                pluginStatusRow(installed: feedback == .success)
            } else if showConfirm {
                confirmRow
            } else {
                MenuRow(icon: "puzzlepiece.extension", label: "Install Plugin") {
                    showConfirm = true
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            aboutSection

            Divider()
                .background(Color.white.opacity(0.1))

            MenuRow(icon: "xmark", label: "Quit", isDestructive: true) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("About")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Button {
                if let url = URL(string: "https://github.com/dsaad68/copilot-island") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    GitHubIcon()
                        .frame(width: 16, height: 16)

                    Text("Repository")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { _ in }

            Button {
                if let url = URL(string: "https://verybad.engineer") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 16)

                    Text("VeryBad.Engineer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

struct GitHubIcon: View {
    var body: some View {
        Image(systemName: "chevron.left.forwardslash.chevron.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
    }
}

    private var confirmRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)

            Text("Install to ~/.copilot?")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Button("Yes") {
                let success = PluginInstaller.install()
                installFeedback = success ? .success : .failure
                showConfirm = false
                if success {
                    sessionStore.pluginInstalled = true
                    // Immediate check
                    sessionStore.checkSetup()
                    // Delayed recheck in case files weren't fully written yet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        sessionStore.checkSetup()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    installFeedback = nil
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.green)

            Button("No") {
                showConfirm = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func pluginStatusRow(installed: Bool) -> some View {
        HStack {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)

            Text("Plugin")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Circle()
                .fill(installed ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(installed ? "Installed" : "Failed")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct MenuRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isDestructive ? .red : .white.opacity(0.6))
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(isDestructive ? .red : .white.opacity(0.8))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
