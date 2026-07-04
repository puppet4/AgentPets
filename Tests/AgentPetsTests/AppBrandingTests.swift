import XCTest
@testable import AgentPets

final class AppBrandingTests: XCTestCase {
    func testDisplayNameMatchesAgentPetsBrand() {
        XCTAssertEqual(AppBranding.bundleName, "AgentPets")
        XCTAssertEqual(AppBranding.displayName, "Agent Pets")
        XCTAssertEqual(AppBranding.iconFileName, "AgentPets.icns")
    }

    func testSourceIconAssetExists() {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconURL = repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("AgentPets")
            .appendingPathComponent("App")
            .appendingPathComponent(AppBranding.iconFileName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path), iconURL.path)
    }
}
