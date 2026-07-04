import XCTest
@testable import AgentPets

final class StatusLegendTests: XCTestCase {
    func testEveryPetStateHasLegendEntry() {
        let legendStates = Set(StatusLegendEntry.all.map(\.state))

        XCTAssertEqual(legendStates, Set(PetState.allCases))
    }

    func testTerminalProcessFallbackIsExplained() {
        let working = StatusLegendEntry.all.first { $0.state == .working }

        XCTAssertTrue(working?.trigger.contains("claude/codex") == true)
        XCTAssertTrue(working?.trigger.contains("CPU >= 2%") == true)
    }

    func testToolSpecificStatesAreExplained() {
        let editing = StatusLegendEntry.all.first { $0.state == .editing }
        let running = StatusLegendEntry.all.first { $0.state == .running }
        let searching = StatusLegendEntry.all.first { $0.state == .searching }

        XCTAssertTrue(editing?.trigger.contains("Edit") == true)
        XCTAssertTrue(editing?.trigger.contains("Write") == true)
        XCTAssertTrue(running?.trigger.contains("Bash") == true)
        XCTAssertTrue(searching?.trigger.contains("WebSearch") == true)
    }
}
