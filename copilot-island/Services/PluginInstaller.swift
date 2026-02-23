//
//  PluginInstaller.swift
//  CopilotIsland
//
//  Installs the Copilot CLI plugin via `copilot plugin install`
//

import Foundation

nonisolated struct PluginInstaller {
    static let pluginSource = "dsaad68/copilot-island:plugin"
    static let pluginName = "copilot-island"

    // MARK: - Public API

    /// Check if `copilot` binary is on PATH using `which`
    static var copilotPath: String? {
        let output = shell("which copilot", captureOutput: true)
        let path = output?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty else { return nil }
        return path
    }

    /// Check if the plugin is installed via `copilot plugin list`
    static var isInstalled: Bool {
        guard let output = shell("copilot plugin list", captureOutput: true) else {
            return false
        }
        return output.contains(pluginName)
    }

    /// Install via `copilot plugin install`. Returns `true` on success.
    @discardableResult
    static func install() -> Bool {
        shell("copilot plugin install \(pluginSource)") != nil
    }

    /// Update via `copilot plugin update`. Returns `true` on success.
    @discardableResult
    static func update() -> Bool {
        shell("copilot plugin update \(pluginName)") != nil
    }

    /// Uninstall via `copilot plugin uninstall`.
    static func uninstall() {
        _ = shell("copilot plugin uninstall \(pluginName)")
    }

    // MARK: - Private

    @discardableResult
    private static func shell(_ command: String, captureOutput: Bool = false) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        // Ensure Homebrew is on PATH since GUI apps don't inherit shell profile
        process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && \(command)"]

        let pipe = Pipe()
        if captureOutput {
            process.standardOutput = pipe
        }

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }

            if captureOutput {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)
            }
            return ""
        } catch {
            return nil
        }
    }
}
