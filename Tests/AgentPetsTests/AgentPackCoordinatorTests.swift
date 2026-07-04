import XCTest
@testable import AgentPets

final class AgentPackCoordinatorTests: XCTestCase {
    func testLegacyConfigWithoutFollowActiveAgentDefaultsToTrue() throws {
        let json = """
        {
          "version": 1,
          "activePack": "legacy-animal-pack",
          "packsDir": "~/Library/Application Support/AgentPets/packs",
          "fps": 12,
          "showLabel": true,
          "labelMaxChars": 24,
          "autoForeground": true,
          "minStateDurationMs": 300,
          "successHoldSeconds": 3,
          "errorHoldSeconds": 4,
          "foregroundOnEvents": ["SessionStart"],
          "stateSpriteMap": {
            "idle": "idle"
          },
          "stateLabelPolicy": {
            "showOn": ["working"]
          },
          "language": "zh"
        }
        """

        let config = try JSONDecoder().decode(PetConfig.self, from: Data(json.utf8))

        XCTAssertTrue(config.followActiveAgent)
    }

    func testUnsupportedPackNormalizesToClaudeWhenFollowModeIsOff() {
        var config = PetConfig.default
        config.followActiveAgent = false
        config.activePack = "legacy-animal-pack"

        let updated = AgentPackCoordinator.normalizeProductPack(config, preferredAgent: nil)

        XCTAssertEqual(updated.activePack, AgentPackCoordinator.claudePackID)
    }

    func testManualSelectionDisablesAutomaticFollow() {
        let updated = AgentPackCoordinator.applyManualSelection(
            packID: AgentPackCoordinator.codexPackID,
            to: .default
        )

        XCTAssertFalse(updated.followActiveAgent)
        XCTAssertEqual(updated.activePack, AgentPackCoordinator.codexPackID)
    }

    func testProductSelectionPreservesAutomaticFollowWhenEnabled() {
        let updated = AgentPackCoordinator.applyProductSelection(
            packID: AgentPackCoordinator.codexPackID,
            to: .default
        )

        XCTAssertTrue(updated.followActiveAgent)
        XCTAssertEqual(updated.activePack, AgentPackCoordinator.codexPackID)
    }

    func testAutomaticFollowMapsKnownAgentsToTheirPackIDs() {
        XCTAssertEqual(
            AgentPackCoordinator.applyDetectedAgent(.claude, to: .default).activePack,
            AgentPackCoordinator.claudePackID
        )
        XCTAssertEqual(
            AgentPackCoordinator.applyDetectedAgent(.codex, to: .default).activePack,
            AgentPackCoordinator.codexPackID
        )
    }

    func testReEnablingAutomaticFollowImmediatelyUsesLastKnownAgent() {
        let manual = AgentPackCoordinator.applyManualSelection(
            packID: AgentPackCoordinator.codexPackID,
            to: .default
        )

        let updated = AgentPackCoordinator.setFollowActiveAgent(
            true,
            currentAgent: .claude,
            config: manual
        )

        XCTAssertTrue(updated.followActiveAgent)
        XCTAssertEqual(updated.activePack, AgentPackCoordinator.claudePackID)
    }

    func testInactiveSnapshotKeepsMostRecentPackIdentity() {
        let config = AgentPackCoordinator.applyDetectedAgent(.codex, to: .default)

        let updated = AgentPackCoordinator.applyDetectedAgent(nil, to: config)

        XCTAssertEqual(updated.activePack, AgentPackCoordinator.codexPackID)
    }

    func testTaskDrivenFollowUsesTopRankedTaskAgent() {
        let tasks = [
            AgentTaskSnapshot.stub(
                agent: .claude,
                state: .listening,
                lastActivityAt: .distantPast,
                host: .iTerm2
            ),
            AgentTaskSnapshot.stub(
                agent: .codex,
                state: .working,
                lastActivityAt: .now,
                host: .iTerm2
            )
        ]

        let updated = AgentPackCoordinator.applyDetectedTasks(tasks, to: .default)

        XCTAssertEqual(updated.activePack, AgentPackCoordinator.codexPackID)
    }

    func testManualLockedConfigIgnoresDetectedAgentSnapshot() {
        let manual = AgentPackCoordinator.applyManualSelection(
            packID: BundledPetPackRenderer.defaultPackID,
            to: .default
        )

        let updated = AgentPackCoordinator.applyDetectedAgent(.codex, to: manual)

        XCTAssertEqual(updated, manual)
    }

    func testFollowModeWithUnsupportedPackAndNoCurrentAgentDefaultsToClaudePack() {
        var config = PetConfig.default
        config.activePack = Pack.placeholderName
        config.followActiveAgent = true

        let updated = AgentPackCoordinator.applyDetectedAgent(nil, to: config)

        XCTAssertEqual(updated.activePack, AgentPackCoordinator.claudePackID)
        XCTAssertTrue(updated.followActiveAgent)
    }

    func testFollowModeWithUnsupportedPackAndCodexAgentNormalizesToCodexPack() {
        var config = PetConfig.default
        config.activePack = Pack.placeholderName
        config.followActiveAgent = true

        let updated = AgentPackCoordinator.applyDetectedAgent(.codex, to: config)

        XCTAssertEqual(updated.activePack, AgentPackCoordinator.codexPackID)
        XCTAssertTrue(updated.followActiveAgent)
    }

    func testManualLockedUnsupportedPackRemainsUnchanged() {
        var config = PetConfig.default
        config.activePack = Pack.placeholderName
        config.followActiveAgent = false

        let updated = AgentPackCoordinator.normalizeProductPack(config, preferredAgent: .codex)

        XCTAssertEqual(updated.activePack, AgentPackCoordinator.codexPackID)
    }
}
