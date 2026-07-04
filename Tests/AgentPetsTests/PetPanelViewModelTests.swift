import AppKit
import XCTest
@testable import AgentPets

final class PetPanelViewModelTests: XCTestCase {
    func testPanelStartsCollapsed() {
        let model = PetPanelViewModel()

        XCTAssertEqual(model.mode, .collapsed)
    }

    func testToggleExpandsThenCollapsesPanel() {
        var model = PetPanelViewModel()

        model.toggle()
        XCTAssertEqual(model.mode, .expanded)

        model.toggle()
        XCTAssertEqual(model.mode, .collapsed)
    }

    func testCollapsesAfterTaskActivationRequest() {
        var model = PetPanelViewModel(mode: .expanded)

        model.collapseAfterTaskActivation()

        XCTAssertEqual(model.mode, .collapsed)
    }

    func testExpandedTaskOrderingUsesMostRecentActivity() {
        let earlier = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        let tasks = [
            AgentTaskSnapshot.stub(id: "older", title: "Older", lastActivityAt: earlier),
            AgentTaskSnapshot.stub(id: "newer", title: "Newer", lastActivityAt: later)
        ]

        let ordered = PetPanelViewModel.orderedTasks(tasks)

        XCTAssertEqual(ordered.map(\.id), ["newer", "older"])
    }

    func testCollapsedStatusDotMapsStateBuckets() {
        XCTAssertEqual(PetPanelViewModel.dotAccent(for: .offline), .gray)
        XCTAssertEqual(PetPanelViewModel.dotAccent(for: .listening), .blue)
        XCTAssertEqual(PetPanelViewModel.dotAccent(for: .thinking), .violet)
        XCTAssertEqual(PetPanelViewModel.dotAccent(for: .working), .aqua)
        XCTAssertEqual(PetPanelViewModel.dotAccent(for: .success), .green)
        XCTAssertEqual(PetPanelViewModel.dotAccent(for: .error), .red)
    }

    func testPanelPlacementDefaultsToBottomRightCornerInset() {
        let placement = PetPanelPlacement()

        let frame = placement.frame(
            for: .collapsed,
            taskCount: 0,
            in: NSRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(frame.origin.x, 316, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 16, accuracy: 0.001)
        XCTAssertEqual(frame.width, 168, accuracy: 0.001)
        XCTAssertEqual(frame.height, 168, accuracy: 0.001)
    }

    func testManualPlacementPreservesBottomTrailingAnchorAcrossResize() {
        var placement = PetPanelPlacement()
        placement.capture(frame: NSRect(x: 400, y: 30, width: 168, height: 168))

        let frame = placement.frame(
            for: .expanded,
            taskCount: 2,
            in: NSRect(x: 0, y: 0, width: 900, height: 700)
        )

        XCTAssertEqual(frame.maxX, 568, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 30, accuracy: 0.001)
        XCTAssertEqual(frame.width, 296, accuracy: 0.001)
    }

    func testManualPlacementClampsBackInsideVisibleScreen() {
        var placement = PetPanelPlacement()
        placement.capture(frame: NSRect(x: 600, y: -20, width: 168, height: 168))

        let frame = placement.frame(
            for: .collapsed,
            taskCount: 0,
            in: NSRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(frame.origin.x, 316, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 16, accuracy: 0.001)
    }

    @MainActor
    func testPanelUpdateContentReusesExistingHostingView() {
        let model = PetModel()
        let panel = PetPanel(
            model: model,
            config: .default,
            pack: .empty,
            mode: .collapsed,
            placement: PetPanelPlacement(),
            onTap: {},
            onActivateTask: { _ in }
        )
        let initialContentView = panel.contentView

        panel.updateContent(
            model: model,
            config: .default,
            pack: .empty,
            mode: .expanded,
            onTap: {},
            onActivateTask: { _ in }
        )

        XCTAssertTrue(initialContentView === panel.contentView)
    }

    func testDragSessionUsesScreenSpaceDeltaForWindowOrigin() {
        let session = PetPanelDragSession(
            startFrame: NSRect(x: 100, y: 40, width: 168, height: 168),
            startScreenPoint: CGPoint(x: 600, y: 300)
        )

        let origin = session.frameOrigin(
            for: CGPoint(x: 640, y: 320),
            within: NSRect(x: 0, y: 0, width: 900, height: 700)
        )

        XCTAssertEqual(origin.x, 140, accuracy: 0.001)
        XCTAssertEqual(origin.y, 60, accuracy: 0.001)
    }

    func testDragSessionClampsWindowInsideVisibleScreen() {
        let session = PetPanelDragSession(
            startFrame: NSRect(x: 300, y: 20, width: 168, height: 168),
            startScreenPoint: CGPoint(x: 500, y: 200)
        )

        let origin = session.frameOrigin(
            for: CGPoint(x: 900, y: -200),
            within: NSRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin.x, 316, accuracy: 0.001)
        XCTAssertEqual(origin.y, 16, accuracy: 0.001)
    }
}
