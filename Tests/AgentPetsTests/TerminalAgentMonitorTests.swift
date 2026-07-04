import XCTest
@testable import AgentPets

final class TerminalAgentMonitorTests: XCTestCase {
    func testCodexProcessWithCpuActivityMapsToWorking() {
        let psOutput = """
        PID PPID TTY STAT %CPU COMM COMMAND
        15330 14003 ttys000 S+ 12.5 codex codex
        """

        let snapshot = TerminalAgentSnapshot.parse(psOutput: psOutput)

        XCTAssertEqual(snapshot.primaryAgent, .codex)
        XCTAssertEqual(snapshot.suggestedState, .working)
        XCTAssertEqual(snapshot.processes.first?.tty, "ttys000")
    }

    func testCodexProcessFromMacOSPsOutputMapsToWorking() {
        let psOutput = """
          PID  PPID TTY      STAT  %CPU COMM             ARGS
        15330 14003 ttys000  S+     2.9 codex            codex
        18464 15330 ??       Ss     0.0 /bin/zsh         /bin/zsh -lc /bin/ps -axo pid,ppid,tty,stat,pcpu,comm,args
        """

        let snapshot = TerminalAgentSnapshot.parse(psOutput: psOutput)

        XCTAssertEqual(snapshot.primaryAgent, .codex)
        XCTAssertEqual(snapshot.suggestedState, .working)
        XCTAssertEqual(snapshot.activeProcessCount, 1)
    }

    func testParseReturnsAllClaudeAndCodexProcessesWithTTY() {
        let psOutput = """
          PID  PPID TTY      STAT  %CPU COMM             ARGS
        36166 14003 ttys000  S+     5.5 codex            codex
        64365 63983 ttys002  S+     0.0 claude           claude
        """

        let snapshot = TerminalAgentSnapshot.parse(psOutput: psOutput)

        XCTAssertEqual(snapshot.processes.count, 2)
        XCTAssertEqual(snapshot.processes.map(\.tty), ["ttys000", "ttys002"])
        XCTAssertEqual(snapshot.primaryProcess?.agent, .codex)
        XCTAssertEqual(snapshot.suggestedState, .working)
    }

    func testParseIgnoresCodexAppHelperProcessesWithoutTTY() {
        let psOutput = """
          PID  PPID TTY      STAT  %CPU COMM             ARGS
        36166 14003 ttys000  S+     5.5 codex            codex resume 019f-demo
        50476 50130 ??       S      0.0 /Applications/Co /Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled
        """

        let snapshot = TerminalAgentSnapshot.parse(psOutput: psOutput)

        XCTAssertEqual(snapshot.processes.count, 1)
        XCTAssertEqual(snapshot.processes.map(\.tty), ["ttys000"])
        XCTAssertEqual(snapshot.primaryAgent, .codex)
        XCTAssertEqual(snapshot.activeProcessCount, 1)
    }

    func testIdleClaudeProcessMapsToListening() {
        let psOutput = """
        PID PPID TTY STAT %CPU COMM COMMAND
        2142 14003 ttys002 S+ 0.0 claude claude --resume abc
        """

        let snapshot = TerminalAgentSnapshot.parse(psOutput: psOutput)

        XCTAssertEqual(snapshot.primaryAgent, .claude)
        XCTAssertEqual(snapshot.suggestedState, .listening)
    }

    @MainActor
    func testMonitorStartPublishesInjectedSnapshot() {
        var snapshots: [TerminalAgentSnapshot] = []
        let monitor = TerminalAgentMonitor(
            psOutputProvider: {
                """
                PID PPID TTY STAT %CPU COMM COMMAND
                15330 14003 ttys000 S+ 12.5 codex codex
                """
            },
            onSnapshot: { snapshots.append($0) }
        )

        monitor.start()
        monitor.stop()

        XCTAssertEqual(snapshots.first?.primaryAgent, .codex)
        XCTAssertEqual(snapshots.first?.suggestedState, .working)
    }

    func testDefaultPackIsBundledCutePetNotPlaceholder() {
        XCTAssertEqual(PetConfig.default.activePack, BundledPetPackRenderer.defaultPackID)
    }
}
