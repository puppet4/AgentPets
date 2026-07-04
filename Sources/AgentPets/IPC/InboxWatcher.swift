import Foundation

/// Watches `~/Library/Application Support/AgentPets/inbox/` for JSON files
/// dropped by `pet-notify.sh`. Each file → decoded `HookEvent` → deleted.
@MainActor
final class InboxWatcher {
    private let dir: URL
    private let onEvent: (HookEvent) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let corruptDir: URL

    init(dir: URL, onEvent: @escaping (HookEvent) -> Void) {
        self.dir = dir
        self.onEvent = onEvent
        self.corruptDir = dir.appendingPathComponent("_corrupt")
    }

    func start() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)

        // Backlog drain on startup
        drain()

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[InboxWatcher] failed to open \(dir.path)")
            return
        }
        self.fd = fd
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.drain()
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fd >= 0 {
                close(self.fd)
                self.fd = -1
            }
        }
        src.resume()
        self.source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func drain() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let jsons = items
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        for url in jsons {
            guard let data = try? Data(contentsOf: url) else {
                quarantine(url)
                continue
            }
            guard let evt = HookEvent.decode(from: data) else {
                quarantine(url)
                continue
            }
            onEvent(evt)
            try? fm.removeItem(at: url)
        }
    }

    private func quarantine(_ url: URL) {
        let fm = FileManager.default
        let dest = corruptDir.appendingPathComponent(url.lastPathComponent)
        try? fm.moveItem(at: url, to: dest)
    }
}
