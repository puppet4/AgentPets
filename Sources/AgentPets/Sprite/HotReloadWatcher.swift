import Foundation

/// Watches one or more directories via DispatchSource. Calls back on the main queue
/// after a short debounce when any file event fires.
final class HotReloadWatcher {
    private let urls: [URL]
    private let debounce: TimeInterval
    private let onChange: () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fds: [Int32] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "\(AppSupport.bundleIdentifier).hotreload", qos: .utility)

    init(urls: [URL], debounce: TimeInterval = 0.3, onChange: @escaping () -> Void) {
        self.urls = urls
        self.debounce = debounce
        self.onChange = onChange
    }

    func start() {
        stop()
        for url in urls {
            let path = url.path
            // Ensure directory exists (so the FD open succeeds)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else {
                NSLog("[HotReload] failed to open \(path) (errno=\(errno))")
                continue
            }
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .rename, .delete],
                queue: queue
            )
            src.setEventHandler { [weak self] in
                self?.scheduleFire()
            }
            src.setCancelHandler { [weak self] in
                guard let self else { return }
                if let idx = self.fds.firstIndex(of: fd) {
                    self.fds.remove(at: idx)
                }
                close(fd)
            }
            src.resume()
            sources.append(src)
            fds.append(fd)
        }
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        for src in sources { src.cancel() }
        sources.removeAll()
        // fds are closed via cancel handlers
    }

    deinit { stop() }

    private func scheduleFire() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.onChange()
            }
            self.debounceWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounce, execute: item)
        }
    }
}
