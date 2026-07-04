import AppKit
import XCTest
@testable import AgentPets

final class StatusItemControllerTests: XCTestCase {
    @MainActor
    func testPrimaryMenuItemsTargetStatusItemController() {
        let controller = StatusItemController(
            onClickIcon: {},
            onShowPreferences: {},
            onShowStatusLegend: {},
            onTogglePause: { false },
            onToggleGlobal: { false },
            onQuit: {}
        )

        let menu = controller.buildMenu()
        let display = menu.items.first { $0.title == "显示主界面（聚焦本应用）" }
        let preferences = menu.items.first { $0.title == "偏好设置…" }
        let legend = menu.items.first { $0.title == "状态说明…" }

        XCTAssertTrue(display?.target === controller)
        XCTAssertTrue(preferences?.target === controller)
        XCTAssertTrue(legend?.target === controller)
    }

    @MainActor
    func testStatusMenuDoesNotExposeFinderShortcuts() {
        let controller = StatusItemController(
            onClickIcon: {},
            onShowPreferences: {},
            onShowStatusLegend: {},
            onTogglePause: { false },
            onToggleGlobal: { false },
            onQuit: {}
        )

        let titles = controller.buildMenu().items.map(\.title)

        XCTAssertFalse(titles.contains("在 Finder 中显示 pet.json"))
        XCTAssertFalse(titles.contains("在 Finder 中显示精灵包目录"))
    }

    @MainActor
    func testStatusMenuShowsSelectablePetPacks() {
        var selectedPack: String?
        let controller = StatusItemController(
            onClickIcon: {},
            onShowPreferences: {},
            onShowStatusLegend: {},
            taskChoicesProvider: { [] },
            petChoicesProvider: {
                [
                    PetPackMenuChoice(id: "claude-pixel", displayName: "Claude", isActive: true),
                    PetPackMenuChoice(id: "codex-pixel", displayName: "Codex", isActive: false)
                ]
            },
            onSelectPack: { selectedPack = $0 },
            onTogglePause: { false },
            onToggleGlobal: { false },
            onQuit: {}
        )

        let menu = controller.buildMenu()
        controller.menuNeedsUpdate(menu)

        let petMenu = menu.items.first { $0.title == "选择宠物" }
        XCTAssertNotNil(petMenu?.submenu)

        let claude = petMenu?.submenu?.items.first { $0.title == "Claude" }
        let codex = petMenu?.submenu?.items.first { $0.title == "Codex" }

        XCTAssertEqual(claude?.state, .on)
        XCTAssertEqual(codex?.state, .off)
        XCTAssertTrue(codex?.target === controller)

        _ = codex?.target?.perform(codex?.action, with: codex)
        XCTAssertEqual(selectedPack, "codex-pixel")
    }

    @MainActor
    func testStatusMenuShowsTaskSubmenuAndSelectsTask() {
        var selectedTask: String?
        let controller = StatusItemController(
            onClickIcon: {},
            onShowPreferences: {},
            onShowStatusLegend: {},
            taskChoicesProvider: {
                [TaskMenuChoice(id: "tty:ttys000", title: "Codex · Desktop · working", isExactActivation: true)]
            },
            onSelectTask: { selectedTask = $0 },
            petChoicesProvider: { [] },
            onTogglePause: { false },
            onToggleGlobal: { false },
            onQuit: {}
        )

        let menu = controller.buildMenu()
        controller.menuNeedsUpdate(menu)

        let taskMenu = menu.items.first { $0.title == "任务状态" }
        let taskItem = taskMenu?.submenu?.items.first { $0.title == "Codex · Desktop · working" }

        XCTAssertNotNil(taskMenu?.submenu)
        XCTAssertTrue(taskItem?.target === controller)

        _ = taskItem?.target?.perform(taskItem?.action, with: taskItem)
        XCTAssertEqual(selectedTask, "tty:ttys000")
    }
}
