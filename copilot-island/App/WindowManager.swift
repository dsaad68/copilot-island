//
//  WindowManager.swift
//  CopilotIsland
//
//  Manages the notch window lifecycle
//

import AppKit
import os.log

private let logger = Logger(subsystem: "com.copilotisland", category: "Window")

class WindowManager {
    private(set) var windowController: NotchWindowController?

    func setupNotchWindow() -> NotchWindowController? {
        guard let screen = NSScreen.main else {
            logger.warning("No screen found")
            return nil
        }

        if let existingController = windowController {
            existingController.window?.orderOut(nil)
            existingController.window?.close()
            windowController = nil
        }

        windowController = NotchWindowController(screen: screen)
        windowController?.showWindow(nil)

        return windowController
    }
}
