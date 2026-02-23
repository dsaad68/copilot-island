//
//  NotchWindowController.swift
//  CopilotIsland
//
//  Controls the notch window positioning and lifecycle
//

import AppKit
import Combine
import SwiftUI

class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel
    private let screen: NSScreen
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var globalMoveMonitor: Any?
    private var localClickMonitor: Any?

    init(screen: NSScreen) {
        self.screen = screen

        let screenFrame = screen.frame

        // Detect actual notch size from screen
        let hasNotch = screen.safeAreaInsets.top > 0
        let notchWidth: CGFloat = 180
        let notchHeight: CGFloat = hasNotch ? screen.safeAreaInsets.top : 32
        let notchSize = CGSize(width: notchWidth, height: notchHeight)

        let windowHeight: CGFloat = 750
        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )

        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )

        self.viewModel = NotchViewModel(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenFrame,
            windowHeight: windowHeight,
            hasPhysicalNotch: hasNotch
        )

        let notchWindow = NotchPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: notchWindow)

        let hostingController = NotchViewController(viewModel: viewModel)
        notchWindow.contentViewController = hostingController

        notchWindow.setFrame(windowFrame, display: true)

        viewModel.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
            .store(in: &cancellables)

        notchWindow.ignoresMouseEvents = true
        setupGlobalEventMonitors()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.viewModel.performBootAnimation()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalMoveMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
    }

    private func handleStatusChange(_ status: NotchStatus) {
        guard let notchWindow = window as? NotchPanel else { return }

        switch status {
        case .opened:
            notchWindow.ignoresMouseEvents = false
            if viewModel.openReason != .notification {
                NSApp.activate(ignoringOtherApps: true)
                notchWindow.makeKey()
            }
        case .closed, .popping:
            notchWindow.ignoresMouseEvents = true
        }
    }

    /// The notch rect in screen coordinates (for hit testing global events)
    private var notchScreenRect: CGRect {
        let screenFrame = screen.frame
        let notchRect = viewModel.deviceNotchRect
        // Notch is centered at the top of the screen
        // Screen coordinates: origin at bottom-left, y increases upward
        let padding: CGFloat = 10
        return CGRect(
            x: screenFrame.origin.x + (screenFrame.width - notchRect.width) / 2 - padding,
            y: screenFrame.maxY - notchRect.height - padding,
            width: notchRect.width + padding * 2,
            height: notchRect.height + padding * 2
        )
    }

    private func setupGlobalEventMonitors() {
        // Global monitor: detect clicks on the notch when our window ignores mouse events
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return }
            let clickLocation = NSEvent.mouseLocation

            if self.viewModel.status == .closed || self.viewModel.status == .popping {
                if self.notchScreenRect.contains(clickLocation) {
                    DispatchQueue.main.async {
                        self.viewModel.notchOpen(reason: .click)
                    }
                }
            }
        }

        // Global monitor: detect mouse movement near the notch for hover effect
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self = self else { return }
            // Only track hover when closed — opened state handles its own events
            guard self.viewModel.status == .closed else { return }
        }

        // Local monitor: detect clicks outside the opened panel to close it
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            guard self.viewModel.status == .opened else { return event }

            guard let notchWindow = self.window else { return event }
            let locationInWindow = event.locationInWindow

            // Check if click is inside the content area
            if let contentView = notchWindow.contentView,
               contentView.hitTest(locationInWindow) != nil {
                return event // Click is on our content, let it through
            }

            // Click is outside content — close the notch
            DispatchQueue.main.async {
                self.viewModel.notchClose()
            }
            return event
        }
    }
}
