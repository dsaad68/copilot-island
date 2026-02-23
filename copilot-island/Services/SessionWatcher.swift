//
//  SessionWatcher.swift
//  CopilotIsland
//
//  Watches ~/.copilot/session-state/ for new sessions and tail-watches
//  events.jsonl to drive all session state from the file system.
//

import Foundation

class SessionWatcher {
    var onSessionStart: ((_ cwd: String, _ sessionId: String) -> Void)?
    var onSessionEnd: (() -> Void)?
    var onPhaseChange: ((_ phase: SessionPhase) -> Void)?
    var onPrompt: ((_ prompt: String) -> Void)?
    var onModelChange: ((_ model: String) -> Void)?
    var onTurnStart: (() -> Void)?
    var onTurnEnd: (() -> Void)?

    /// True while replaying existing events on attach (before watching for new ones)
    private(set) var isReplaying: Bool = false

    private var dirSource: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var fileSource: DispatchSourceFileSystemObject?
    private var fileHandle: FileHandle?
    private var currentSessionDir: URL?
    private var knownSessionDirs: Set<String> = []

    private static let sessionStateDir: URL = HistoricalSession.sessionStateDir

    // MARK: - Lifecycle

    /// Call after setting callbacks to begin watching for sessions
    func start() {
        startWatchingDirectory()
        attachToLatestSession()
    }

    deinit {
        stopFileWatcher()
        stopDirectoryWatcher()
    }

    // MARK: - Directory Watching

    private func startWatchingDirectory() {
        let dir = Self.sessionStateDir
        let fm = FileManager.default

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        if let entries = try? fm.contentsOfDirectory(atPath: dir.path) {
            knownSessionDirs = Set(entries)
        }

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        dirFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.directoryDidChange() }
        source.setCancelHandler { close(fd) }
        source.resume()
        dirSource = source
    }

    private func stopDirectoryWatcher() {
        dirSource?.cancel()
        dirSource = nil
    }

    private func directoryDidChange() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: Self.sessionStateDir.path) else { return }

        let current = Set(entries)
        let newEntries = current.subtracting(knownSessionDirs)
        knownSessionDirs = current

        guard !newEntries.isEmpty else { return }

        if let newest = newEntries
            .map({ Self.sessionStateDir.appendingPathComponent($0) })
            .max(by: {
                let a = (try? fm.attributesOfItem(atPath: $0.path))?[.modificationDate] as? Date ?? .distantPast
                let b = (try? fm.attributesOfItem(atPath: $1.path))?[.modificationDate] as? Date ?? .distantPast
                return a < b
            })
        {
            attachToSession(directory: newest)
        }
    }

    // MARK: - Session Attachment

    private func attachToLatestSession() {
        let fm = FileManager.default
        let baseDir = Self.sessionStateDir
        guard let entries = try? fm.contentsOfDirectory(atPath: baseDir.path) else { return }

        let latest = entries
            .map { baseDir.appendingPathComponent($0) }
            .max(by: {
                let a = (try? fm.attributesOfItem(atPath: $0.path))?[.modificationDate] as? Date ?? .distantPast
                let b = (try? fm.attributesOfItem(atPath: $1.path))?[.modificationDate] as? Date ?? .distantPast
                return a < b
            })

        guard let sessionDir = latest else { return }

        let eventsPath = sessionDir.appendingPathComponent("events.jsonl").path
        guard fm.fileExists(atPath: eventsPath) else { return }

        attachToSession(directory: sessionDir)
    }

    private func attachToSession(directory: URL) {
        // Guard against re-attaching to the same session
        if currentSessionDir == directory { return }

        stopFileWatcher()
        currentSessionDir = directory

        let sessionId = directory.lastPathComponent
        let cwd = readCwdFromWorkspace(directory: directory) ?? ""
        onSessionStart?(cwd, sessionId)

        waitForEventsFile(directory: directory)
    }

    private func waitForEventsFile(directory: URL) {
        let eventsPath = directory.appendingPathComponent("events.jsonl").path
        if FileManager.default.fileExists(atPath: eventsPath) {
            startFileWatcher(path: eventsPath)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.currentSessionDir == directory else { return }
                self.waitForEventsFile(directory: directory)
            }
        }
    }

    // MARK: - File Watching

    private func startFileWatcher(path: String) {
        guard let fh = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return }

        // Read ALL existing content to establish current state
        isReplaying = true
        let existingData = fh.readDataToEndOfFile()
        if !existingData.isEmpty, let text = String(data: existingData, encoding: .utf8) {
            processLines(text)
        }
        isReplaying = false

        // Now fh is positioned at EOF — new events will be read from here
        fileHandle = fh

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fh.fileDescriptor,
            eventMask: .extend,
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.readNewLines() }
        source.setCancelHandler { try? fh.close() }
        source.resume()
        fileSource = source
    }

    private func stopFileWatcher() {
        fileSource?.cancel()
        fileSource = nil
        fileHandle = nil
    }

    private func readNewLines() {
        guard let fh = fileHandle else { return }
        let data = fh.readDataToEndOfFile()
        guard !data.isEmpty,
              let text = String(data: data, encoding: .utf8) else { return }
        processLines(text)
    }

    private func processLines(_ text: String) {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let json = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            let eventData = json["data"] as? [String: Any]

            switch type {
            case "session.start":
                // cwd lives at data.context.cwd in the real event format
                let context = eventData?["context"] as? [String: Any]
                let cwd = context?["cwd"] as? String ?? eventData?["cwd"] as? String ?? ""
                let sessionId = eventData?["sessionId"] as? String ?? currentSessionDir?.lastPathComponent ?? ""
                onSessionStart?(cwd, sessionId)

            case "user.message":
                if let content = eventData?["content"] as? String {
                    onPrompt?(content)
                }
                onPhaseChange?(.processing)

            case "tool.execution_start":
                let toolName = eventData?["toolName"] as? String ?? "tool"
                onPhaseChange?(.runningTool(name: toolName))

            case "tool.execution_complete":
                onPhaseChange?(.processing)

            case "assistant.turn_start":
                onTurnStart?()
                onPhaseChange?(.processing)

            case "assistant.turn_end":
                onTurnEnd?()
                onPhaseChange?(.idle)

            case "session.error":
                let errorMsg = eventData?["error"] as? String ?? "Unknown error"
                onPhaseChange?(.error(message: errorMsg))

            case "session.model_change":
                if let model = eventData?["model"] as? String {
                    onModelChange?(model)
                }

            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func readCwdFromWorkspace(directory: URL) -> String? {
        let path = directory.appendingPathComponent("workspace.yaml").path
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("cwd:") else { continue }
            return String(trimmed.dropFirst(4))
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }
}
