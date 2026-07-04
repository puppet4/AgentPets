import AppKit
import XCTest
@testable import AgentPets

final class AppRuntimePresentationTests: XCTestCase {
    func testActivationPolicyRunsAsAccessoryApp() {
        XCTAssertEqual(AppRuntimePresentation.activationPolicy, .accessory)
    }
}
