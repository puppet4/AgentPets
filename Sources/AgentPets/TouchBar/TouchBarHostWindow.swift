import AppKit

/// Custom NSWindow that owns the Touch Bar. Overrides `makeTouchBar()` so
/// the system invokes our `TouchBarController` whenever the bar needs to
/// (re)build. Also forces the window to be key-capable — necessary because
/// NSTouchBar is only queried for the KEY window of the foreground app.
final class TouchBarHostWindow: NSWindow {
    var touchBarBuilder: (() -> NSTouchBar?)?
    private static var makeCount = 0

    override func makeTouchBar() -> NSTouchBar? {
        Self.makeCount += 1
        let count = Self.makeCount
        let path = AppSupport.supportDir.appendingPathComponent("logs/touchbar.log")
        let line = "[\(Date())] makeTouchBar called #\(count), keyWindow=\(isKeyWindow), isMain=\(isMainWindow)\n"
        if let data = line.data(using: .utf8) {
            try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let handle = try? FileHandle(forWritingTo: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: path)
            }
        }
        NSLog("[TouchBarHostWindow] makeTouchBar #\(count), key=\(isKeyWindow) main=\(isMainWindow)")
        return touchBarBuilder?()
    }

    /// Critical: without this, a borderless window can't become the key window,
    /// so the system never asks it for `makeTouchBar()`.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}