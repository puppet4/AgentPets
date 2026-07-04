import AppKit

/// Monitors which app is in the foreground and tells us when Claude/Codex hosts
/// become active so we can mirror the current task state, and when they lose
/// focus so we stop.
@MainActor
final class WorkspaceMonitor {
    private let onActivated: (String, String) -> Void   // (name, bundleId)
    private let onDeactivated: () -> Void
    private var monitoredFrontmost: String?   // bundleId of current monitored frontmost
    private var observer: NSObjectProtocol?

    private let monitoredBundleIds = Set([
        "com.apple.Terminal",
        "com.anthropic.claude-code",
        "com.github.copilot",
        "com.microsoft.VSCode",
        "com.googlecode.iterm2",
        "com.pbatards.Warp",
    ])

    init(
        onMonitoredAppActivated: @escaping (String, String) -> Void,
        onMonitoredAppDeactivated: @escaping () -> Void
    ) {
        self.onActivated = onMonitoredAppActivated
        self.onDeactivated = onMonitoredAppDeactivated
    }

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return }
                self.handle(note, app: bundleId, name: name)
            }
        }
    }

    func stop() {
        if let o = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
            observer = nil
        }
    }

    private func handle(_ note: Notification, app bundleId: String, name: String) {
        let wasFrontmost = monitoredFrontmost

        if monitoredBundleIds.contains(bundleId) {
            // Monitored app became frontmost.
            if monitoredFrontmost != bundleId {
                monitoredFrontmost = bundleId
                log("→ \(name) (\(bundleId)) became frontmost")
                onActivated(name, bundleId)
            }
        } else if wasFrontmost != nil {
            // A monitored app was frontmost and now something else is.
            // Only fire deactivated if OUR monitored app was the one that left.
            if wasFrontmost != nil {
                monitoredFrontmost = nil
                log("← monitored app lost front")
                onDeactivated()
            }
        }
    }

    private func log(_ msg: String) {
        let dir = AppSupport.supportDir.appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("workspace.log")
        let line = "[\(Date().ISO8601Format())] \(msg)\n"
        if let d = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: f) {
                h.seekToEndOfFile(); h.write(d); try? h.close()
            } else { try? d.write(to: f) }
        }
    }
}
