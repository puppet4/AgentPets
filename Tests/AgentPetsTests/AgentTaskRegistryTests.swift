import XCTest
@testable import AgentPets

final class AgentTaskRegistryTests: XCTestCase {
    func testRegistryToleratesDuplicateHostSessionsForSameTTY() {
        let now = Date(timeIntervalSince1970: 100)
        let registry = AgentTaskRegistry(now: { now })
        let process = TerminalAgentProcessSnapshot(
            pid: 36166,
            ppid: 14003,
            tty: "ttys000",
            agent: .codex,
            cpu: 4.0
        )

        registry.record(
            processSnapshot: TerminalAgentSnapshot(
                processes: [process],
                primaryProcess: process,
                primaryAgent: .codex,
                suggestedState: .working,
                activeProcessCount: 1
            ),
            hostSessions: [
                HostSessionInfo(
                    host: .iTerm2,
                    tty: "ttys000",
                    title: "Desktop (codex)",
                    location: .iTerm2(windowID: 1010, tabIndex: 1, tty: "ttys000"),
                    activationCapability: .exact
                ),
                HostSessionInfo(
                    host: .iTerm2,
                    tty: "ttys000",
                    title: "Duplicate Desktop (codex)",
                    location: .iTerm2(windowID: 1010, tabIndex: 1, tty: "ttys000"),
                    activationCapability: .exact
                )
            ]
        )

        XCTAssertEqual(registry.tasks.count, 1)
        XCTAssertEqual(registry.tasks.first?.tty, "ttys000")
    }

    func testHookEventDecodesSessionMetadata() throws {
        let json = """
        {
          "hook_event_name": "PreToolUse",
          "tool_name": "Read",
          "task_meta": {
            "term_program": "iTerm.app",
            "term_session_id": "w0t0p0:abc",
            "tty": "ttys000",
            "cwd": "/Users/kangjialv/Desktop"
          }
        }
        """

        let event = HookEvent.decode(from: Data(json.utf8))

        XCTAssertEqual(event?.taskMeta?.tty, "ttys000")
        XCTAssertEqual(event?.taskMeta?.termProgram, "iTerm.app")
    }

    func testRegistryUpgradesProcessTaskWithHookStateAndKeepsRecentTitle() {
        let now = Date(timeIntervalSince1970: 100)
        let registry = AgentTaskRegistry(now: { now })
        let process = TerminalAgentProcessSnapshot(
            pid: 36166,
            ppid: 14003,
            tty: "ttys000",
            agent: .codex,
            cpu: 4.0
        )
        registry.record(
            processSnapshot: TerminalAgentSnapshot(
                processes: [process],
                primaryProcess: process,
                primaryAgent: .codex,
                suggestedState: .working,
                activeProcessCount: 1
            ),
            hostSessions: [
                HostSessionInfo(
                    host: .iTerm2,
                    tty: "ttys000",
                    title: "Desktop (codex)",
                    location: .iTerm2(windowID: 1010, tabIndex: 1, tty: "ttys000"),
                    activationCapability: .exact
                )
            ]
        )

        registry.record(event: HookEvent(
            kind: "PreToolUse",
            tool: "Read",
            file: nil,
            cmd: nil,
            prompt: nil,
            stop: nil,
            error: nil,
            source: nil,
            reason: nil,
            ts: nil,
            taskMeta: HookEvent.TaskMeta(
                termProgram: "iTerm.app",
                termSessionID: "w0t0p0:abc",
                iTermSessionID: "w0t0p0:abc",
                tty: "ttys000",
                cwd: "/Users/kangjialv/Desktop"
            )
        ))

        let task = registry.tasks.first

        XCTAssertEqual(task?.title, "Desktop (codex)")
        XCTAssertEqual(task?.state, .reading)
    }
}
