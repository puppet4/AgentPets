import AppKit

/// Wraps the private `DFRFoundation` framework to keep an NSTouchBar visible
/// across all foreground apps. Uses private Apple APIs — may break on future
/// macOS releases. Opt-in via the menu bar's "Always Show on Touch Bar" item.
@MainActor
final class GlobalTouchBar {
    private(set) var isActive: Bool = false
    private weak var touchBar: NSTouchBar?

    /// Try to enable global Touch Bar. Returns true if the runtime accepted
    /// the request (actual visibility depends on macOS policy).
    @discardableResult
    func enable(touchBar: NSTouchBar) -> Bool {
        self.touchBar = touchBar

        guard let systemWideClass = NSClassFromString("DFRSystemWideTouchBar") else {
            NSLog("[GlobalTouchBar] DFRSystemWideTouchBar class not found — private API unavailable on this macOS")
            return false
        }

        // sharedTouchBar is a class method — call via ObjC runtime on the class object.
        let cls = systemWideClass as AnyObject
        let sharedSelector = NSSelectorFromString("sharedTouchBar")
        guard cls.responds(to: sharedSelector),
              let sharedRaw = cls.perform(sharedSelector)?.takeUnretainedValue(),
              let shared = sharedRaw as? NSObject else {
            NSLog("[GlobalTouchBar] sharedTouchBar unavailable")
            return false
        }

        let presentSelector = NSSelectorFromString("presentSystemBar:onScreen:")
        guard shared.responds(to: presentSelector) else {
            NSLog("[GlobalTouchBar] presentSystemBar:onScreen: not available")
            return false
        }

        _ = shared.perform(presentSelector, with: touchBar, with: NSNumber(value: 0))
        isActive = true
        NSLog("[GlobalTouchBar] enabled — Touch Bar should appear system-wide")
        return true
    }

    func disable() {
        guard let systemWideClass = NSClassFromString("DFRSystemWideTouchBar") else { return }
        let cls = systemWideClass as AnyObject
        let sharedSelector = NSSelectorFromString("sharedTouchBar")
        guard let sharedRaw = cls.perform(sharedSelector)?.takeUnretainedValue(),
              let shared = sharedRaw as? NSObject,
              let bar = touchBar else {
            isActive = false
            return
        }
        let dismissSelector = NSSelectorFromString("dismissSystemBar:")
        if shared.responds(to: dismissSelector) {
            _ = shared.perform(dismissSelector, with: bar)
        }
        isActive = false
        NSLog("[GlobalTouchBar] disabled")
    }
}