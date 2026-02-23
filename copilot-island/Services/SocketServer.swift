//
//  SocketServer.swift
//  CopilotIsland
//
//  Unix domain socket server for receiving events from hook scripts
//

import Foundation

struct PendingToolApproval: Sendable {
    let requestId: String
    let toolName: String
    let toolArgs: String?
    let cwd: String
}

final class SocketServer: @unchecked Sendable {
    static let socketPath = "/tmp/copilot-island.sock"

    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let eventHandler: @MainActor (CopilotEvent) -> Void
    private let approvalHandler: @MainActor (PendingToolApproval) -> Void
    private let acceptQueue = DispatchQueue(label: "com.copilotisland.socket.accept")
    private let clientQueue = DispatchQueue(label: "com.copilotisland.socket.client", attributes: .concurrent)

    private let pendingLock = NSLock()
    private var pendingClients: [String: Int32] = [:]

    init(
        eventHandler: @escaping @MainActor (CopilotEvent) -> Void,
        approvalHandler: @escaping @MainActor (PendingToolApproval) -> Void
    ) {
        self.eventHandler = eventHandler
        self.approvalHandler = approvalHandler
    }

    func start() throws {
        guard !isRunning else { return }

        unlink(Self.socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw SocketError.failedToCreateSocket
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        Self.socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
                _ = strcpy(dest, ptr)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            close(serverSocket)
            throw SocketError.failedToBind
        }

        guard listen(serverSocket, 5) == 0 else {
            close(serverSocket)
            throw SocketError.failedToListen
        }

        isRunning = true

        acceptQueue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverSocket, sockPtr, &clientAddrLen)
                }
            }

            guard clientSocket >= 0 else {
                continue
            }

            clientQueue.async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        // Set a read timeout so we don't block forever waiting for more data
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(clientSocket, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            data.append(contentsOf: buffer[0..<bytesRead])
            // Check if we have a complete JSON object (last non-whitespace char is '}')
            if let lastNonWS = data.last(where: { $0 != 0x0A && $0 != 0x0D && $0 != 0x20 && $0 != 0x09 }),
               lastNonWS == UInt8(ascii: "}") {
                break
            }
        }

        guard !data.isEmpty else {
            close(clientSocket)
            return
        }

        let decoder = JSONDecoder()
        guard let event = try? decoder.decode(CopilotEvent.self, from: data) else {
            close(clientSocket)
            return
        }

        if event.event == .preToolUse {
            let requestId = UUID().uuidString
            let approval = PendingToolApproval(
                requestId: requestId,
                toolName: event.toolName ?? "unknown",
                toolArgs: event.toolArgs,
                cwd: event.cwd
            )

            pendingLock.lock()
            pendingClients[requestId] = clientSocket
            pendingLock.unlock()

            let handler = approvalHandler
            DispatchQueue.main.async {
                handler(approval)
            }
            // Socket stays open — will be closed when respondToPermission is called
        } else {
            close(clientSocket)

            let handler = eventHandler
            DispatchQueue.main.async {
                handler(event)
            }
        }
    }

    func respondToPermission(requestId: String, allow: Bool) {
        clientQueue.async { [weak self] in
            guard let self else { return }

            self.pendingLock.lock()
            let clientSocket = self.pendingClients.removeValue(forKey: requestId)
            self.pendingLock.unlock()

            guard let fd = clientSocket else { return }

            // Set SO_NOSIGPIPE on the socket so write returns EPIPE instead of SIGPIPE
            var on: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

            let response: [String: String]
            if allow {
                response = ["permissionDecision": "allow"]
            } else {
                response = [
                    "permissionDecision": "deny",
                    "permissionDecisionReason": "Denied by user"
                ]
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                // Write may fail with EPIPE if bridge script already timed out — that's fine
                jsonString.withCString { ptr in
                    _ = send(fd, ptr, strlen(ptr), 0)
                }
            }
            close(fd)
        }
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }

        // Close any pending client sockets
        pendingLock.lock()
        for (_, fd) in pendingClients {
            close(fd)
        }
        pendingClients.removeAll()
        pendingLock.unlock()

        unlink(Self.socketPath)
    }
}

enum SocketError: Error {
    case failedToCreateSocket
    case failedToBind
    case failedToListen
}
