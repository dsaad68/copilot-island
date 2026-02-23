//
//  AppDelegate.swift
//  CopilotIsland
//
//  Main application delegate for Copilot Island
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?

    static var shared: AppDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip single-instance check when running as test host so the test runner can connect
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests, !ensureSingleInstance() {
            NSApplication.shared.terminate(nil)
            return
        }

        windowManager = WindowManager()
        _ = windowManager?.setupNotchWindow()

        SessionStore.shared.startServer()
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    private func ensureSingleInstance() -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.copilotisland.app"
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID
        }

        if runningApps.count > 1 {
            if let existingApp = runningApps.first(where: { $0.processIdentifier != getpid() }) {
                existingApp.activate()
            }
            return false
        }

        return true
    }
}
