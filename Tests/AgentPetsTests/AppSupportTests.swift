import XCTest
@testable import AgentPets

final class AppSupportTests: XCTestCase {
    func testSupportDirectoryUsesAgentPetsName() {
        XCTAssertTrue(
            AppSupport.supportDir.path.hasSuffix("/Library/Application Support/AgentPets"),
            AppSupport.supportDir.path
        )
    }

    func testDefaultPacksDirectoryUsesAgentPetsName() {
        XCTAssertEqual(PetConfig.default.packsDir, "~/Library/Application Support/AgentPets/packs")
    }

    @MainActor
    func testTouchBarIdentifiersUseAgentPetsNamespace() {
        XCTAssertEqual(TouchBarController.itemID.rawValue, "com.agentpets.app.principal")
        XCTAssertEqual(TouchBarController.barID, "com.agentpets.app.bar")
    }

    func testPrepareSupportDirectoryCreatesCurrentSupportDirectory() throws {
        let homeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpets-home-\(UUID().uuidString)", isDirectory: true)

        let preparedDir = try AppSupport.prepareSupportDirectory(homeDirectory: homeURL)

        XCTAssertEqual(preparedDir, AppSupport.supportDir(homeDirectory: homeURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: preparedDir.path))
    }
}
