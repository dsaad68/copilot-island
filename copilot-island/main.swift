//
//  main.swift
//  CopilotIsland
//
//  Application entry point
//

import AppKit

final class Application: NSObject {
    static func main() {
        // Ignore SIGPIPE so writing to a closed socket returns an error
        // instead of terminating the process (signal 13)
        signal(SIGPIPE, SIG_IGN)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

Application.main()
