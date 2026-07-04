import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PetModel()
    var config: PetConfig!
    var packManager: PackManager!
    var touchBarCtl: TouchBarController?
    var inboxWatcher: InboxWatcher?
    var workspaceMonitor: WorkspaceMonitor?
    var terminalAgentMonitor: TerminalAgentMonitor?
    var petConfigWatcher: HotReloadWatcher?
    var stateStore = StateStore()
    var prefsWindow: PreferencesWindowController?
    var statusLegendWindow: StatusLegendWindowController?
    var statusItem: StatusItemController?
    var petPanel: PetPanel?
    var touchBarHostWindow: TouchBarHostWindow?
    let globalTouchBar = GlobalTouchBar()
    private var petPanelViewModel = PetPanelViewModel()
    private var petPanelPlacement = PetPanelPlacement()
    private var panelOutsideClickLocalMonitor: Any?
    private var panelOutsideClickGlobalMonitor: Any?
    private var isPaused: Bool = false
    private var isGlobalTouchBar: Bool = false
    /// Bundle ID of the currently frontmost monitored app (nil if none).
    private var activeMonitoredApp: String?
    private var lastDetectedAgent: TerminalAgent?
    private let taskRegistry = AgentTaskRegistry()
    private let hostSessionIndex = HostSessionIndex()
    private let taskActivator = TaskActivator()

    func applicationDidFinishLaunching(_ n: Notification) {
        log("applicationDidFinishLaunching pid=\(ProcessInfo.processInfo.processIdentifier)")

        let args = CommandLine.arguments
        if args.count >= 2, args[1] == "--gen-bundled-pet-packs" {
            do {
                let written = try BundledPetPackRenderer.writeAll(
                    to: AppSupport.supportDir.appendingPathComponent("packs")
                )
                print("✓ Bundled pet packs written: \(written.map(\.lastPathComponent).joined(separator: ", "))")
            } catch {
                FileHandle.standardError.write(Data("✗ Failed: \(error)\n".utf8))
                exit(1)
            }
            exit(0)
        }

        // 后台 accessory 模式：保留菜单栏和窗口，但不占 Dock。
        NSApp.setActivationPolicy(AppRuntimePresentation.activationPolicy)
        setupMainMenu()
        installStatusItem()
        NSApp.activate(ignoringOtherApps: true)

        // 加载配置
        let supportDir = (try? AppSupport.prepareSupportDirectory()) ?? AppSupport.supportDir
        config = PetConfig.load(from: supportDir.appendingPathComponent("pet.json"))
        config = AgentPackCoordinator.reconcileFollowMode(currentAgent: nil, config: config)
        ensureBundledPetPacks()
        stateStore.restore(model: model, config: config)
        log("config loaded activePack=\(config.activePack)")

        // Pack 管理器
        packManager = PackManager(packsDir: config.resolvedPacksDir())
        let activeName = config.activePack.isEmpty
            ? (stateStore.loadActivePack() ?? Pack.placeholderName)
            : config.activePack
        Task { @MainActor in
            await packManager.bootstrap(activeName: activeName)
            var reconciledConfig = self.config ?? PetConfig.default
            reconciledConfig.activePack = self.packManager.activePack?.id ?? activeName
            reconciledConfig = AgentPackCoordinator.reconcileFollowMode(
                currentAgent: self.lastDetectedAgent,
                config: reconciledConfig
            )
            self.applyConfig(reconciledConfig, writeToDisk: true)
            self.setupPetPanel()
            self.rebuildTouchBar()
            self.watchPetConfig()
            self.log("pack bootstrap done")
        }

        // WorkspaceMonitor: 监听 Claude Code / Terminal 前台切换
        workspaceMonitor = WorkspaceMonitor(
            onMonitoredAppActivated: { [weak self] appName, bundleId in
                guard let self else { return }
                self.handleMonitoredAppActivated(name: appName, bundleId: bundleId)
            },
            onMonitoredAppDeactivated: { [weak self] in
                guard let self else { return }
                self.handleMonitoredAppDeactivated()
            }
        )
        workspaceMonitor?.start()

        terminalAgentMonitor = TerminalAgentMonitor { [weak self] snapshot in
            guard let self else { return }
            self.handleTerminalAgentSnapshot(snapshot)
        }
        log("terminal agent monitor starting")
        terminalAgentMonitor?.start()
        log("terminal agent monitor started")

        // Hook inbox 监控
        let inboxDir = supportDir.appendingPathComponent("inbox")
        try? FileManager.default.createDirectory(at: inboxDir, withIntermediateDirectories: true)
        inboxWatcher = InboxWatcher(dir: inboxDir) { [weak self] event in
            guard let self else { return }
            self.model.handle(event: event, config: self.config, appDelegate: self)
            self.taskRegistry.record(event: event)
            self.syncTaskPresentation()
            self.stateStore.persist(model: self.model)
            self.logEvent(event)
        }
        inboxWatcher?.start()
        log("inbox watcher started")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ n: Notification) {
        inboxWatcher?.stop()
        workspaceMonitor?.stop()
        terminalAgentMonitor?.stop()
        petConfigWatcher?.stop()
        removePanelOutsideClickMonitors()
        touchBarHostWindow?.orderOut(nil)
        statusItem?.uninstall()
        globalTouchBar.disable()
    }

    // MARK: - 主菜单

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 \(AppBranding.displayName)",
                       action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                       keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let prefsItem = NSMenuItem(title: "偏好设置…",
                                  action: #selector(handleShowPreferences),
                                  keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        let statusLegendItem = NSMenuItem(title: "状态说明…",
                                          action: #selector(handleShowStatusLegend),
                                          keyEquivalent: "")
        statusLegendItem.target = self
        appMenu.addItem(statusLegendItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 \(AppBranding.displayName)",
                       action: #selector(NSApplication.hide(_:)),
                       keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 \(AppBranding.displayName)",
                       action: #selector(NSApplication.terminate(_:)),
                       keyEquivalent: "q")

        let winItem = NSMenuItem()
        mainMenu.addItem(winItem)
        let winMenu = NSMenu(title: "窗口")
        winItem.submenu = winMenu
        winMenu.addItem(withTitle: "最小化",
                      action: #selector(NSWindow.performMiniaturize(_:)),
                      keyEquivalent: "m")
        winMenu.addItem(withTitle: "缩放",
                      action: #selector(NSWindow.performZoom(_:)),
                      keyEquivalent: "")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 宠物面板 (右下角, non-activating)

    private func setupPetPanel() {
        let panel = PetPanel(
            model: model,
            config: config ?? PetConfig.default,
            pack: packManager?.activePack ?? Pack.empty,
            mode: petPanelViewModel.mode,
            placement: petPanelPlacement,
            onTap: { [weak self] in self?.togglePetPanel() },
            onActivateTask: { [weak self] task in self?.activateTaskAndCollapse(task) }
        )
        panel.onFrameChanged = { [weak self] frame in
            self?.petPanelPlacement.capture(frame: frame)
        }
        panel.orderFrontRegardless()
        petPanel = panel
        panel.updateLayout(
            mode: petPanelViewModel.mode,
            taskCount: model.tasks.count,
            placement: petPanelPlacement,
            animated: false
        )
        updateOutsideClickMonitoring()
        log("pet panel ordered front")
    }

    func refreshPetPanel() {
        guard let panel = petPanel else { return }
        panel.updateLayout(
            mode: petPanelViewModel.mode,
            taskCount: model.tasks.count,
            placement: petPanelPlacement,
            animated: true
        )
        panel.updateContent(
            model: model,
            config: config ?? PetConfig.default,
            pack: packManager?.activePack ?? Pack.empty,
            mode: petPanelViewModel.mode,
            onTap: { [weak self] in self?.togglePetPanel() },
            onActivateTask: { [weak self] task in self?.activateTaskAndCollapse(task) }
        )
        updateOutsideClickMonitoring()
    }

    /// 短暂抢前台(0.3s)让 Touch Bar 显示我们的猫,然后让用户切回 Terminal。
    /// Called when a monitored app (Terminal/Claude Code/etc.) comes to front.
    private func handleMonitoredAppActivated(name: String, bundleId: String) {
        activeMonitoredApp = bundleId
        log("monitored app activated: \(name) (\(bundleId))")

        // Enable global Touch Bar so cat shows even though we're not the key app.
        if !globalTouchBar.isActive, let bar = touchBarCtl?.touchBar {
            let ok = globalTouchBar.enable(touchBar: bar)
            isGlobalTouchBar = ok
            log("globalTouchBar.enable = \(ok)")
        }
        // Keep our panel visible in corner always.
        petPanel?.orderFrontRegardless()
    }

    /// Called when the monitored app loses frontmost status.
    private func handleMonitoredAppDeactivated() {
        activeMonitoredApp = nil
        log("monitored app deactivated")
        // Disable global Touch Bar since user switched away.
        if globalTouchBar.isActive {
            globalTouchBar.disable()
            isGlobalTouchBar = false
        }
    }

    private func handleTerminalAgentSnapshot(_ snapshot: TerminalAgentSnapshot) {
        taskRegistry.record(
            processSnapshot: snapshot,
            hostSessions: hostSessionIndex.sessions()
        )
        syncTaskPresentation()

        if let topTask = AgentTaskSnapshot.aggregate(from: model.tasks) {
            lastDetectedAgent = topTask.agent
            log("terminal tasks detected top=\(topTask.agent.rawValue) state=\(topTask.state.rawValue) count=\(snapshot.activeProcessCount)")
        } else {
            log("terminal agent inactive")
        }
    }

    // MARK: - Touch Bar

    private func rebuildTouchBar() {
        let ctl = TouchBarController(
            model: model,
            configProvider: { [weak self] in self?.config ?? PetConfig.default },
            packProvider: { [weak self] in self?.packManager?.activePack },
            onTap: { [weak self] in self?.showPreferences() }
        )
        self.touchBarCtl = ctl
        if let panel = petPanel {
            panel.touchBar = ctl.touchBar
            panel.touchBarProvider = { [weak self] in self?.touchBarCtl?.touchBar }
            log("touchBar set on panel")
        }
        touchBarHostWindow?.touchBarBuilder = { [weak self] in self?.touchBarCtl?.touchBar }
    }

    private func showTouchBar() {
        if touchBarCtl == nil {
            rebuildTouchBar()
        }
        let host = ensureTouchBarHostWindow()
        host.touchBarBuilder = { [weak self] in self?.touchBarCtl?.touchBar }
        petPanel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        host.orderFrontRegardless()
        host.makeKeyAndOrderFront(nil)
        host.makeMain()
        log("touchBar host ordered key=\(host.isKeyWindow) main=\(host.isMainWindow)")
    }

    private func ensureTouchBarHostWindow() -> TouchBarHostWindow {
        if let touchBarHostWindow {
            return touchBarHostWindow
        }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10, height: 10)
        let rect = NSRect(x: screen.minX + 1, y: screen.minY + 1, width: 2, height: 2)
        let window = TouchBarHostWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.04
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 2, height: 2))
        touchBarHostWindow = window
        return window
    }

    // MARK: - 偏好设置

    private func showPreferences() {
        if prefsWindow == nil {
            prefsWindow = PreferencesWindowController()
        }
        prefsWindow?.show(
            model: model,
            config: config,
            packManager: packManager,
            onReload: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.packManager?.reloadAll(activeName: self.config.activePack)
                    self.rebuildTouchBar()
                    self.refreshPetPanel()
                }
            },
            onConfigChanged: { [weak self] fresh in
                guard let self else { return fresh }
                let resolved = AgentPackCoordinator.setFollowActiveAgent(
                    fresh.followActiveAgent,
                    currentAgent: self.lastDetectedAgent,
                    config: fresh
                )
                self.applyConfig(resolved, writeToDisk: true)
                return resolved
            }
        )
    }

    private func showStatusLegend() {
        if statusLegendWindow == nil {
            statusLegendWindow = StatusLegendWindowController()
        }
        statusLegendWindow?.show()
    }

    private func ensureBundledPetPacks() {
        do {
            _ = try BundledPetPackRenderer.writeAll(to: config.resolvedPacksDir())
        } catch {
            log("bundled pet pack bootstrap failed: \(error)")
        }
    }

    private func applyConfig(_ newConfig: PetConfig, writeToDisk: Bool) {
        let previousPack = config?.activePack
        config = AgentPackCoordinator.normalizeProductPack(newConfig, preferredAgent: lastDetectedAgent)
        model.apply(config)
        stateStore.persistActivePack(config.activePack)
        if writeToDisk {
            try? config.write(to: AppSupport.supportDir.appendingPathComponent("pet.json"))
        }

        Task { @MainActor in
            if previousPack != config.activePack {
                await self.packManager?.switchPack(to: config.activePack)
            }
            self.rebuildTouchBar()
            self.refreshPetPanel()
        }
    }

    private func selectPackFromMenu(_ id: String) {
        let updated = AgentPackCoordinator.applyProductSelection(packID: id, to: config)
        guard updated != config else { return }
        applyConfig(updated, writeToDisk: true)
    }

    @objc private func handleShowPreferences() { showPreferences() }
    @objc private func handleShowStatusLegend() { showStatusLegend() }

    // MARK: - 状态栏图标

    private func installStatusItem() {
        statusItem = StatusItemController(
            onClickIcon: { [weak self] in self?.showTouchBar() },
            onShowPreferences: { [weak self] in self?.showPreferences() },
            onShowStatusLegend: { [weak self] in self?.showStatusLegend() },
            taskChoicesProvider: { [weak self] in
                guard let self else { return [] }
                return self.model.tasks.map { task in
                    TaskMenuChoice(
                        id: task.id,
                        title: "\(task.agent.rawValue.capitalized) · \(task.title) · \(task.state.rawValue)",
                        isExactActivation: task.activationCapability == .exact
                    )
                }
            },
            onSelectTask: { [weak self] id in
                guard let self, let task = self.model.tasks.first(where: { $0.id == id }) else { return }
                self.activateTask(task)
            },
            petChoicesProvider: { [weak self] in
                guard let self else { return [] }
                return (self.packManager?.productPacks ?? []).map {
                    PetPackMenuChoice(
                        id: $0.id,
                        displayName: $0.displayName,
                        isActive: $0.id == self.config?.activePack
                    )
                }
            },
            onSelectPack: { [weak self] id in
                self?.selectPackFromMenu(id)
            },
            onTogglePause: { [weak self] in
                self?.isPaused.toggle()
                self?.model.fps = self?.isPaused == true ? 0 : max(1, (self?.config.fps ?? 12))
                return self?.isPaused ?? false
            },
            onToggleGlobal: { [weak self] in
                guard let self else { return false }
                if globalTouchBar.isActive {
                    globalTouchBar.disable()
                    return false
                } else if let bar = touchBarCtl?.touchBar {
                    return globalTouchBar.enable(touchBar: bar)
                }
                return false
            },
            onQuit: { [weak self] in
                self?.globalTouchBar.disable()
                self?.inboxWatcher?.stop()
                self?.workspaceMonitor?.stop()
                self?.statusItem?.uninstall()
                NSApp.terminate(nil)
            }
        )
        statusItem?.install()
    }

    // MARK: - pet.json 热重载

    private func watchPetConfig() {
        let url = AppSupport.supportDir.appendingPathComponent("pet.json")
        petConfigWatcher?.stop()
        petConfigWatcher = HotReloadWatcher(urls: [url], debounce: 0.5) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let fresh = PetConfig.load(from: url)
                let resolved = AgentPackCoordinator.applyDetectedTasks(
                    self.model.tasks,
                    to: AgentPackCoordinator.normalizeProductPack(
                        fresh,
                        preferredAgent: self.lastDetectedAgent
                    )
                )
                let effective = fresh.followActiveAgent
                    ? resolved
                    : AgentPackCoordinator.normalizeProductPack(
                        fresh,
                        preferredAgent: self.lastDetectedAgent
                    )
                self.applyConfig(effective, writeToDisk: effective != fresh)
            }
        }
        petConfigWatcher?.start()
    }

    private func syncTaskPresentation() {
        let tasks = taskRegistry.tasks
        model.tasks = tasks

        if config.followActiveAgent {
            let updatedConfig = AgentPackCoordinator.applyDetectedTasks(tasks, to: config)
            if updatedConfig != config {
                applyConfig(updatedConfig, writeToDisk: true)
            }
        }

        if let topTask = AgentTaskSnapshot.aggregate(from: tasks) {
            model.setState(topTask.state)
            lastDetectedAgent = topTask.agent
        } else {
            model.setState(.idle)
        }
        stateStore.persist(model: model)
    }

    private func activateTask(_ task: AgentTaskSnapshot) {
        do {
            _ = try taskActivator.activate(task)
        } catch {
            log("task activation failed: \(error)")
        }
    }

    private func activateTaskAndCollapse(_ task: AgentTaskSnapshot) {
        activateTask(task)
        petPanelViewModel.collapseAfterTaskActivation()
        refreshPetPanel()
    }

    private func togglePetPanel() {
        petPanelViewModel.toggle()
        petPanel?.orderFrontRegardless()
        refreshPetPanel()
    }

    private func collapsePetPanel() {
        guard petPanelViewModel.mode == .expanded else { return }
        petPanelViewModel.collapse()
        refreshPetPanel()
    }

    private func updateOutsideClickMonitoring() {
        if petPanelViewModel.mode == .expanded {
            installPanelOutsideClickMonitors()
        } else {
            removePanelOutsideClickMonitors()
        }
    }

    private func installPanelOutsideClickMonitors() {
        guard panelOutsideClickLocalMonitor == nil, panelOutsideClickGlobalMonitor == nil else { return }

        panelOutsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            guard self.petPanelViewModel.mode == .expanded else { return event }
            guard let panel = self.petPanel else { return event }

            let point = NSEvent.mouseLocation
            if !panel.frame.contains(point) {
                self.collapsePetPanel()
            }
            return event
        }

        panelOutsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.petPanelViewModel.mode == .expanded else { return }
                guard let panel = self.petPanel else { return }

                let point = NSEvent.mouseLocation
                if !panel.frame.contains(point) {
                    self.collapsePetPanel()
                }
            }
        }
    }

    private func removePanelOutsideClickMonitors() {
        if let local = panelOutsideClickLocalMonitor {
            NSEvent.removeMonitor(local)
            panelOutsideClickLocalMonitor = nil
        }
        if let global = panelOutsideClickGlobalMonitor {
            NSEvent.removeMonitor(global)
            panelOutsideClickGlobalMonitor = nil
        }
    }

    // MARK: - 日志

    private func log(_ msg: String) {
        let logsDir = AppSupport.supportDir.appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let logFile = logsDir.appendingPathComponent("startup.log")
        let line = "[\(Date().ISO8601Format())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: logFile) { h.seekToEndOfFile(); h.write(data); try? h.close() }
            else { try? data.write(to: logFile) }
        }
    }

    private func logEvent(_ event: HookEvent) {
        let logsDir = AppSupport.supportDir.appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let logFile = logsDir.appendingPathComponent("events.log")
        let line = "[\(Date().ISO8601Format())] \(event.kind) tool=\(event.tool ?? "-") src=\(event.source ?? "-")\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: logFile) { h.seekToEndOfFile(); h.write(data); try? h.close() }
            else { try? data.write(to: logFile) }
        }
    }
}
