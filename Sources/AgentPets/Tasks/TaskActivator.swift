import AppKit
import Foundation

final class TaskActivator {
    enum ActivationRoute: Equatable {
        case exact(String)
        case windowOnly(String)
        case unavailable
    }

    typealias AppleScriptRunner = (_ lines: [String]) throws -> Void
    typealias BundleActivator = (_ bundleID: String) -> Bool

    private let appleScriptRunner: AppleScriptRunner
    private let bundleActivator: BundleActivator
    private(set) var lastRoute: ActivationRoute = .unavailable

    init(
        appleScriptRunner: @escaping AppleScriptRunner = TaskActivator.runAppleScript,
        bundleActivator: @escaping BundleActivator = TaskActivator.activateBundle
    ) {
        self.appleScriptRunner = appleScriptRunner
        self.bundleActivator = bundleActivator
    }

    @discardableResult
    func activate(_ task: AgentTaskSnapshot) throws -> ActivationRoute {
        switch task.location {
        case let .iTerm2(windowID, tabIndex, tty):
            try appleScriptRunner([
                "tell application \"iTerm2\"",
                "activate",
                "set targetWindow to first window whose id is \(windowID)",
                "tell targetWindow",
                "select",
                "set current tab to tab \(tabIndex)",
                "repeat with s in sessions of current tab",
                "if (tty of s as string) is \"/dev/\(tty)\" then",
                "select s",
                "exit repeat",
                "end if",
                "end repeat",
                "end tell",
                "end tell"
            ])
            lastRoute = .exact("iTerm2")
        case let .window(bundleID, _):
            lastRoute = bundleActivator(bundleID) ? .windowOnly(bundleID) : .unavailable
        case .unavailable:
            lastRoute = .unavailable
        }
        return lastRoute
    }

    private static func runAppleScript(_ lines: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = lines.flatMap { ["-e", $0] }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "TaskActivator", code: Int(process.terminationStatus))
        }
    }

    private static func activateBundle(_ bundleID: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return false
        }
        return app.activate()
    }
}
