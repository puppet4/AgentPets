import XCTest
@testable import AgentPets

final class PanelStatusPresentationTests: XCTestCase {
    func testWorkingPresentationUsesChineseProgressCopy() {
        let presentation = PanelStatusPresentation.for(.working)

        XCTAssertEqual(presentation.title, "工作中")
        XCTAssertEqual(presentation.detail, "正在处理任务")
        XCTAssertEqual(presentation.accessibilityLabel, "Agent Pets，工作中，正在处理任务")
    }

    func testOfflinePresentationUsesQuietCopy() {
        let presentation = PanelStatusPresentation.for(.offline)

        XCTAssertEqual(presentation.title, "离线")
        XCTAssertEqual(presentation.detail, "等待 Claude 或 Codex")
        XCTAssertEqual(presentation.accessibilityLabel, "Agent Pets，离线，等待 Claude 或 Codex")
    }

    func testPanelBadgeUsesShortChineseStatusCopy() {
        XCTAssertEqual(PanelStatusPresentation.for(.listening).badgeText, "等输入")
        XCTAssertEqual(PanelStatusPresentation.for(.reading).badgeText, "读代码")
        XCTAssertEqual(PanelStatusPresentation.for(.searching).badgeText, "查资料")
        XCTAssertEqual(PanelStatusPresentation.for(.editing).badgeText, "改文件")
        XCTAssertEqual(PanelStatusPresentation.for(.running).badgeText, "跑命令")
        XCTAssertEqual(PanelStatusPresentation.for(.success).badgeText, "完成啦")
    }

    func testDefaultPanelClickPetsInsteadOfOpeningSettings() {
        XCTAssertEqual(PanelInteractionPolicy.default.primaryClickAction, .pet)
        XCTAssertEqual(PanelInteractionPolicy.default.settingsEntryPoint, .menuBar)
    }
}
