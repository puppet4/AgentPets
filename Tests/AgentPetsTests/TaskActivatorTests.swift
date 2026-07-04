import XCTest
@testable import AgentPets

final class TaskActivatorTests: XCTestCase {
    func testItermTaskUsesExactActivation() throws {
        var invokedLines: [String] = []
        let activator = TaskActivator(
            appleScriptRunner: { invokedLines = $0 },
            bundleActivator: { _ in false }
        )
        let task = AgentTaskSnapshot.stub(
            agent: .codex,
            tty: "ttys000",
            host: .iTerm2,
            location: .iTerm2(windowID: 1010, tabIndex: 1, tty: "ttys000"),
            activationCapability: .exact
        )

        let route = try activator.activate(task)

        XCTAssertEqual(route, .exact("iTerm2"))
        XCTAssertTrue(invokedLines.contains("set current tab to tab 1"))
    }

    func testUnknownHostFallsBackToWindowActivation() throws {
        var activatedBundleID: String?
        let activator = TaskActivator(
            appleScriptRunner: { _ in XCTFail("unexpected AppleScript invocation") },
            bundleActivator: {
                activatedBundleID = $0
                return true
            }
        )
        let task = AgentTaskSnapshot.stub(
            agent: .claude,
            host: .vscode,
            location: .window(bundleID: "com.microsoft.VSCode", title: "Claude Code"),
            activationCapability: .windowOnly
        )

        let route = try activator.activate(task)

        XCTAssertEqual(route, .windowOnly("com.microsoft.VSCode"))
        XCTAssertEqual(activatedBundleID, "com.microsoft.VSCode")
    }
}
