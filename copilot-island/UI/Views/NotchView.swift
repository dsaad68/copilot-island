//
//  NotchView.swift
//  CopilotIsland
//
//  The main dynamic island SwiftUI view with accurate notch shape
//

import SwiftUI

private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

private let minNotchWidth: CGFloat = 204

// Logo-inspired animation constants (unified, professional feel)
private let notchSpringOpen = Animation.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)
private let notchSpringClose = Animation.spring(response: 0.42, dampingFraction: 0.85, blendDuration: 0)
private let notchSpringHover = Animation.spring(response: 0.38, dampingFraction: 0.82)
private let contentAppearAnimation = Animation.easeOut(duration: 0.4)
private let approvalBounceSpring = Animation.spring(response: 0.35, dampingFraction: 0.6)

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var sessionStore = SessionStore.shared
    @State private var isVisible: Bool = false
    @State private var isHovering: Bool = false
    @State private var isBouncing: Bool = false
    @State private var hasReceivedFirstEvent: Bool = false
    @State private var approvalBounceTimer: Timer?
    @State private var approvalAutoTimer: Timer?
    @State private var approvalCountdown: Int = 20
    @State private var showApprovalCLIHint: Bool = false

    @Namespace private var activityNamespace

    private var isProcessing: Bool {
        if case .processing = sessionStore.phase { return true }
        if case .runningTool = sessionStore.phase { return true }
        return false
    }

    private var isIdle: Bool {
        if case .idle = sessionStore.phase { return true }
        return false
    }

    private var hasError: Bool {
        if case .error = sessionStore.phase { return true }
        return false
    }

    private var needsApproval: Bool {
        if case .waitingForApproval = sessionStore.phase { return true }
        return false
    }

    private var hasNewMessage: Bool {
        !sessionStore.sessionsWithNewMessages.isEmpty
    }

    private var baseClosedNotchSize: CGSize {
        CGSize(
            width: viewModel.deviceNotchRect.width,
            height: viewModel.deviceNotchRect.height
        )
    }

    private var expansionWidth: CGFloat {
        if isProcessing || hasError || needsApproval || hasNewMessage {
            return 2 * max(0, baseClosedNotchSize.height - 12) + 60
        }
        return 0
    }

    private var closedNotchSize: CGSize {
        CGSize(
            width: baseClosedNotchSize.width + expansionWidth,
            height: baseClosedNotchSize.height
        )
    }

    private var notchSize: CGSize {
        let size: CGSize
        switch viewModel.status {
        case .closed, .popping:
            size = closedNotchSize
        case .opened:
            size = viewModel.openedSize
        }
        return CGSize(
            width: max(size.width, minNotchWidth),
            height: size.height
        )
    }

    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                notchLayout
            }
        }
        .frame(width: notchSize.width, alignment: .top)
        .padding(
            .horizontal,
            viewModel.status == .opened
                ? cornerRadiusInsets.opened.top
                : cornerRadiusInsets.closed.bottom
        )
        .padding([.horizontal, .bottom], viewModel.status == .opened ? 12 : 0)
        .background(.black)
        .clipShape(currentNotchShape)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, topCornerRadius)
        }
        .shadow(
            color: (viewModel.status == .opened || isHovering) ? .black.opacity(0.7) : .clear,
            radius: 6
        )
        .frame(
            maxHeight: viewModel.status == .opened
                ? notchSize.height
                : closedNotchSize.height,
            alignment: .top
        )
        .animation(viewModel.status == .opened ? notchSpringOpen : notchSpringClose, value: viewModel.status)
        .animation(.smooth, value: isProcessing)
        .animation(.smooth, value: hasError)
        .animation(.smooth, value: needsApproval)
        .animation(.smooth, value: hasNewMessage)
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onAppear {
            isVisible = true
        }
        .onChange(of: viewModel.status) { oldStatus, newStatus in
            handleStatusChange(from: oldStatus, to: newStatus)
        }
        .onChange(of: sessionStore.phase) { _, _ in
            handlePhaseChange()
        }
        .onChange(of: sessionStore.setupPhase) { _, newPhase in
            if newPhase == .done && !sessionStore.pluginInstalled && sessionStore.copilotInstalled {
                isVisible = true
                if viewModel.status == .closed {
                    viewModel.notchOpen(reason: .notification)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(notchSpringHover) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            if viewModel.status != .opened {
                viewModel.notchOpen(reason: .click)
            }
        }
    }

    private var showActivity: Bool {
        isProcessing || hasError || needsApproval || hasNewMessage
    }

    private var isInChatMode: Bool {
        if case .chat = viewModel.contentType { return true }
        return false
    }

    @ViewBuilder
    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .frame(height: closedNotchSize.height)

            if viewModel.status != .closed {
                contentView
                    .frame(width: notchSize.width - 24)
                    .frame(maxWidth: .infinity)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .top)
                                .combined(with: .opacity)
                                .animation(contentAppearAnimation),
                            removal: .opacity.animation(.easeOut(duration: 0.2))
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 0) {
            if showActivity {
                HStack(spacing: 4) {
                    CopilotIcon(size: 14, animate: isProcessing)
                        .matchedGeometryEffect(id: "icon", in: activityNamespace, isSource: showActivity)

                    if hasError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .matchedGeometryEffect(id: "status", in: activityNamespace, isSource: showActivity)
                    }

                    if needsApproval {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .matchedGeometryEffect(id: "status", in: activityNamespace, isSource: showActivity)
                    }
                }
                .frame(width: viewModel.status == .opened ? nil : sideWidth, alignment: .leading)
                .padding(.leading, viewModel.status == .opened ? 8 : 4)
            }

            if viewModel.status == .opened {
                openedHeaderContent
            } else if !showActivity {
                Rectangle()
                    .fill(.clear)
                    .frame(width: closedNotchSize.width - 20)
            } else if isProcessing || hasNewMessage {
                Rectangle()
                    .fill(.clear)
                    .frame(width: baseClosedNotchSize.width - cornerRadiusInsets.closed.top)
            } else {
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top + (isBouncing ? 16 : 0))
            }

            if showActivity {
                if isProcessing {
                    Group {
                        if viewModel.status == .opened {
                            ProcessingSpinner()
                        } else {
                            StarburstView(size: 12)
                        }
                    }
                    .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showActivity)
                    .frame(width: viewModel.status == .opened ? 20 : sideWidth, alignment: .trailing)
                    .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                } else if needsApproval {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.orange.opacity(0.5), radius: 2)
                        .scaleEffect(isBouncing ? 1.3 : 1.0)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth, alignment: .trailing)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                } else if hasError {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth, alignment: .trailing)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                } else if hasNewMessage {
                    Circle()
                        .fill(.white.opacity(0.85))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.logoCyan.opacity(0.5), radius: 3)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth, alignment: .trailing)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                }
            }
        }
        .frame(height: closedNotchSize.height)
    }

    private var sideWidth: CGFloat {
        max(0, closedNotchSize.height - 12) + 30
    }

    @ViewBuilder
    private var openedHeaderContent: some View {
        HStack(spacing: 12) {
            if !showActivity {
                CopilotIcon(size: 14)
                    .matchedGeometryEffect(id: "icon", in: activityNamespace, isSource: !showActivity)
                    .padding(.leading, 8)
            }

            Spacer()

            if !isInChatMode {
                Button {
                    withAnimation(notchSpringHover) {
                        viewModel.toggleMenu()
                    }
                } label: {
                    Image(systemName: viewModel.contentType == .menu ? "xmark" : "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            if needsApproval {
                approvalView
            } else if showApprovalCLIHint {
                cliHintView
            } else if hasError, case .error(let message) = sessionStore.phase {
                errorNotificationView(message: message)
            } else {
                switch viewModel.contentType {
                case .sessions:
                    SessionListView(sessionStore: sessionStore, onSelectSession: { session in
                        withAnimation(notchSpringHover) {
                            viewModel.contentType = .chat(session)
                        }
                    })
                case .menu:
                    NotchMenuView(viewModel: viewModel, sessionStore: sessionStore)
                case .chat(let session):
                    ChatView(session: session, sessionStore: sessionStore) {
                        withAnimation(notchSpringHover) {
                            viewModel.contentType = .sessions
                        }
                    }
                }
            }
        }
        .frame(width: notchSize.width - 24)
    }

    @ViewBuilder
    private var cliHintView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            Text("Approve in your terminal")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text("Hook-based approval is not yet supported by Copilot CLI. Please approve the tool in your terminal to continue.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showApprovalCLIHint = false
                    viewModel.notchClose()
                }
            } label: {
                Text("Dismiss")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var approvalView: some View {
        VStack(spacing: 12) {
            if case .waitingForApproval(let toolName) = sessionStore.phase {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)

                    Text("Tool Approval Required")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(toolName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))

                    if let args = sessionStore.pendingApproval?.toolArgs, !args.isEmpty {
                        Text(args)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    Button {
                        stopApprovalAutoTimer()
                        showApprovalCLIHint = false
                        sessionStore.denyToolUse()
                    } label: {
                        Text("Deny")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopApprovalAutoTimer()
                        sessionStore.autoApproveUntil = Date().addingTimeInterval(10)
                        sessionStore.approveToolUse()
                        showApprovalCLIHint = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopApprovalAutoTimer()
                        sessionStore.autoApproveUntil = Date().addingTimeInterval(10)
                        sessionStore.approveToolUse()
                        showApprovalCLIHint = true
                    } label: {
                        Text("Approve")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                Text("Auto-approve in \(approvalCountdown)s")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func errorNotificationView(message: String) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)

                Text("Error")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation(notchSpringHover) {
                        sessionStore.phase = .idle
                        viewModel.notchClose()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 12)
    }

    private func handlePhaseChange() {
        if !hasReceivedFirstEvent {
            hasReceivedFirstEvent = true
        }

        if needsApproval {
            isVisible = true
            startApprovalBounce()
            if viewModel.status == .closed {
                viewModel.notchOpen(reason: .notification)
            }
        } else if hasError {
            isVisible = true
            stopApprovalBounce()
            if viewModel.status == .closed {
                viewModel.notchOpen(reason: .notification)
            }
            // Auto-dismiss error after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if self.hasError && self.viewModel.status == .opened {
                    withAnimation(notchSpringHover) {
                        self.sessionStore.phase = .idle
                        self.viewModel.notchClose()
                    }
                }
            }
        } else if isProcessing {
            isVisible = true
            stopApprovalBounce()
            if showApprovalCLIHint {
                // Keep notch open to show the CLI hint, auto-dismiss after 10s
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    if self.showApprovalCLIHint {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.showApprovalCLIHint = false
                            if !self.needsApproval && !self.hasError {
                                self.viewModel.notchClose()
                            }
                        }
                    }
                }
            }
        } else if isIdle && hasReceivedFirstEvent {
            isVisible = true
            stopApprovalBounce()
            showApprovalCLIHint = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.isIdle && self.viewModel.status == .closed && !self.sessionStore.sessionActive {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isVisible = false
                    }
                }
            }
        } else {
            stopApprovalBounce()
        }
    }

    private func startApprovalBounce() {
        approvalBounceTimer?.invalidate()
        // Initial bounce
        withAnimation(approvalBounceSpring) {
            isBouncing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(approvalBounceSpring) {
                self.isBouncing = false
            }
        }
        // Repeat bounce every 3 seconds
        approvalBounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                guard self.needsApproval else { return }
                withAnimation(approvalBounceSpring) {
                    self.isBouncing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(approvalBounceSpring) {
                        self.isBouncing = false
                    }
                }
            }
        }
        // Start auto-approve countdown
        startApprovalAutoTimer()
    }

    private func stopApprovalBounce() {
        approvalBounceTimer?.invalidate()
        approvalBounceTimer = nil
        isBouncing = false
        stopApprovalAutoTimer()
    }

    private func startApprovalAutoTimer() {
        stopApprovalAutoTimer()
        approvalCountdown = 20
        approvalAutoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard self.needsApproval else {
                    self.stopApprovalAutoTimer()
                    return
                }
                self.approvalCountdown -= 1
                if self.approvalCountdown <= 0 {
                    self.stopApprovalAutoTimer()
                    self.sessionStore.autoApproveUntil = Date().addingTimeInterval(10)
                    self.sessionStore.approveToolUse()
                    self.showApprovalCLIHint = true
                }
            }
        }
    }

    private func stopApprovalAutoTimer() {
        approvalAutoTimer?.invalidate()
        approvalAutoTimer = nil
    }

    private func handleStatusChange(from oldStatus: NotchStatus, to newStatus: NotchStatus) {
        switch newStatus {
        case .opened, .popping:
            isVisible = true
            // Don't clear per-session unread state on notch open
        case .closed:
            if hasReceivedFirstEvent && !sessionStore.sessionActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self.viewModel.status == .closed && self.isIdle && !self.isProcessing && !self.hasError && !self.needsApproval && !self.sessionStore.sessionActive {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.isVisible = false
                        }
                    }
                }
            }
        }
    }
}
