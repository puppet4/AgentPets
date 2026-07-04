import AppKit

struct PetPackMenuChoice: Sendable {
    let id: String
    let displayName: String
    let isActive: Bool
}

struct TaskMenuChoice: Sendable {
    let id: String
    let title: String
    let isExactActivation: Bool
}

/// Menu-bar icon (NSStatusItem) so the user always has a visible handle to the app.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let onClickIcon: () -> Void
    private let onShowPreferences: () -> Void
    private let onShowStatusLegend: () -> Void
    private let taskChoicesProvider: () -> [TaskMenuChoice]
    private let onSelectTask: (String) -> Void
    private let petChoicesProvider: () -> [PetPackMenuChoice]
    private let onSelectPack: (String) -> Void
    private let onTogglePause: () -> Bool?
    private let onToggleGlobal: () -> Bool?
    private let onQuit: () -> Void
    private var isPaused: Bool = false
    private var isGlobalTouchBar: Bool = false
    private var pauseMenuItem: NSMenuItem?
    private var globalMenuItem: NSMenuItem?
    private var taskMenuItem: NSMenuItem?
    private var petMenuItem: NSMenuItem?

    init(
        onClickIcon: @escaping () -> Void,
        onShowPreferences: @escaping () -> Void,
        onShowStatusLegend: @escaping () -> Void,
        taskChoicesProvider: @escaping () -> [TaskMenuChoice] = { [] },
        onSelectTask: @escaping (String) -> Void = { _ in },
        petChoicesProvider: @escaping () -> [PetPackMenuChoice] = { [] },
        onSelectPack: @escaping (String) -> Void = { _ in },
        onTogglePause: @escaping () -> Bool?,
        onToggleGlobal: @escaping () -> Bool?,
        onQuit: @escaping () -> Void
    ) {
        self.onClickIcon = onClickIcon
        self.onShowPreferences = onShowPreferences
        self.onShowStatusLegend = onShowStatusLegend
        self.taskChoicesProvider = taskChoicesProvider
        self.onSelectTask = onSelectTask
        self.petChoicesProvider = petChoicesProvider
        self.onSelectPack = onSelectPack
        self.onTogglePause = onTogglePause
        self.onToggleGlobal = onToggleGlobal
        self.onQuit = onQuit
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let symbols = ["terminal.fill", "chevron.left.forwardslash.chevron.right", "cpu.fill", "command.square"]
            var image: NSImage?
            for name in symbols {
                if let sfi = NSImage(systemSymbolName: name, accessibilityDescription: AppBranding.displayName) {
                    sfi.isTemplate = true
                    image = sfi
                    break
                }
            }
            if let img = image {
                button.image = img
            } else {
                button.title = "AI"
            }
            button.toolTip = "\(AppBranding.displayName) — 点击打开菜单"
        }

        let menu = buildMenu()
        item.menu = menu
        statusItem = item
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(actionItem(title: "显示主界面（聚焦本应用）",
                                action: #selector(handleClickIcon)))
        menu.addItem(actionItem(title: "偏好设置…",
                                action: #selector(handlePrefs),
                                keyEquivalent: ","))
        menu.addItem(actionItem(title: "状态说明…",
                                action: #selector(handleStatusLegend)))

        menu.addItem(NSMenuItem.separator())

        taskMenuItem = NSMenuItem(title: "任务状态", action: nil, keyEquivalent: "")
        taskMenuItem?.submenu = NSMenu(title: "任务状态")
        menu.addItem(taskMenuItem!)

        petMenuItem = NSMenuItem(title: "选择宠物", action: nil, keyEquivalent: "")
        petMenuItem?.submenu = NSMenu(title: "选择宠物")
        menu.addItem(petMenuItem!)

        menu.addItem(NSMenuItem.separator())

        pauseMenuItem = NSMenuItem(title: "暂停动画",
                                 action: #selector(handlePause), keyEquivalent: "p")
        pauseMenuItem?.target = self
        menu.addItem(pauseMenuItem!)

        globalMenuItem = NSMenuItem(title: "同时在 Touch Bar 显示",
                                  action: #selector(handleToggleGlobal), keyEquivalent: "")
        globalMenuItem?.target = self
        menu.addItem(globalMenuItem!)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "退出 \(AppBranding.displayName)",
                              action: #selector(handleQuit), keyEquivalent: "q"))
        menu.items.last?.target = self

        return menu
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    func uninstall() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseMenuItem?.title = isPaused ? "继续动画" : "暂停动画"
        globalMenuItem?.state = isGlobalTouchBar ? .on : .off
        rebuildTaskMenu()
        rebuildPetMenu()
    }

    @objc private func handleClickIcon()  { onClickIcon() }
    @objc private func handlePrefs()       { onShowPreferences() }
    @objc private func handleStatusLegend() { onShowStatusLegend() }
    @objc private func handleTaskSelection(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onSelectTask(id)
    }
    @objc private func handlePackSelection(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onSelectPack(id)
    }
    @objc private func handlePause()       { isPaused = onTogglePause() ?? isPaused }
    @objc private func handleToggleGlobal() { isGlobalTouchBar = onToggleGlobal() ?? isGlobalTouchBar }
    @objc private func handleQuit()        { onQuit() }

    private func rebuildTaskMenu() {
        guard let submenu = taskMenuItem?.submenu else { return }
        submenu.removeAllItems()

        let choices = taskChoicesProvider()
        guard !choices.isEmpty else {
            let empty = NSMenuItem(title: "暂无活跃任务", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }

        for choice in choices {
            let item = NSMenuItem(
                title: choice.title,
                action: #selector(handleTaskSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = choice.id
            item.toolTip = choice.isExactActivation ? "可精确切回任务" : "当前先切回对应应用窗口"
            submenu.addItem(item)
        }
    }

    private func rebuildPetMenu() {
        guard let submenu = petMenuItem?.submenu else { return }
        submenu.removeAllItems()

        let choices = petChoicesProvider()
        guard !choices.isEmpty else {
            let empty = NSMenuItem(title: "暂无可选宠物", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }

        for choice in choices {
            let item = NSMenuItem(
                title: choice.displayName,
                action: #selector(handlePackSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = choice.id
            item.state = choice.isActive ? .on : .off
            submenu.addItem(item)
        }
    }
}
