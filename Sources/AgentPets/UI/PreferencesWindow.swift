import SwiftUI
import AppKit

/// 偏好设置窗口.点击 Touch Bar 上的宠物或菜单栏 → "偏好设置" 唤起.
struct PreferencesView: View {
    @Bindable var model: PetModel
    @State var config: PetConfig
    let packManager: PackManager
    let onDismiss: () -> Void
    let onReload: () -> Void
    let onConfigChanged: (PetConfig) -> PetConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppBranding.displayName)
                .font(.title2.bold())

            // --- 精灵包 ---
            GroupBox("精灵包") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("跟随当前活跃 Agent 自动切换", isOn: $config.followActiveAgent)
                        .onChange(of: config.followActiveAgent) { _, _ in persist() }
                    Text(config.followActiveAgent
                         ? "自动模式: 会跟随当前活跃的 Agent 自动切换到对应精灵包。"
                         : "手动模式: 保持当前选择的精灵包，直到你再次开启自动模式。")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("当前:")
                        Picker("", selection: $config.activePack) {
                            ForEach(packManager.productPacks, id: \.id) { pack in
                                Text(pack.displayName).tag(pack.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                        .onChange(of: config.activePack) { _, newValue in
                            config = AgentPackCoordinator.applyProductSelection(packID: newValue, to: config)
                            persist()
                        }
                    }
                    HStack(spacing: 12) {
                        Button("打开精灵包目录") {
                            NSWorkspace.shared.open(packManager.packsDir)
                        }
                        Button("立即刷新") {
                            onReload()
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // --- 动画 ---
            GroupBox("动画") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("帧率: \(Int(config.fps)) fps")
                        Slider(value: $config.fps, in: 6...24, step: 1) {
                            Text("FPS")
                        }
                        .onChange(of: config.fps) { _, _ in persist() }
                    }
                    Toggle("显示状态文字", isOn: $config.showLabel)
                        .onChange(of: config.showLabel) { _, _ in persist() }
                }
                .padding(.vertical, 4)
            }

            // --- 前台行为 ---
            GroupBox("前台行为") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("自动抢前台(收到事件时)", isOn: $config.autoForeground)
                        .onChange(of: config.autoForeground) { _, _ in persist() }
                    Text("触发条件:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(knownEvents, id: \.self) { ev in
                        Toggle(ev, isOn: Binding(
                            get: { config.foregroundOnEvents.contains(ev) },
                            set: { isOn in
                                if isOn {
                                    if !config.foregroundOnEvents.contains(ev) {
                                        config.foregroundOnEvents.append(ev)
                                    }
                                } else {
                                    config.foregroundOnEvents.removeAll { $0 == ev }
                                }
                                persist()
                            }
                        ))
                        .disabled(!config.autoForeground)
                    }
                }
                .padding(.vertical, 4)
            }

            // --- 监控范围 ---
            GroupBox("监控范围") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前会聚合监控多个 Claude/Codex 任务，并在右下角与菜单栏展示任务列表。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("只有你点击任务项时，应用才会尝试切回对应任务；后台状态变化不会自动乱弹。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("iTerm2 当前支持精确跳转；其他宿主会按可用能力回退到对应应用窗口。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button("打开 pet.json") {
                    NSWorkspace.shared.open(supportDir().appendingPathComponent("pet.json"))
                }
                Button("完成") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440, height: 620)
    }

    private let knownEvents = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "PostToolUseFailure", "Notification", "Stop", "SubagentStop",
        "PreCompact", "SessionEnd"
    ]

    private func persist() {
        config = onConfigChanged(config)
        try? config.write(to: supportDir().appendingPathComponent("pet.json"))
        model.apply(config)
    }

    private func supportDir() -> URL {
        AppSupport.supportDir
    }
}

/// 偏好设置窗口控制器.
@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?

    func show(
        model: PetModel,
        config: PetConfig,
        packManager: PackManager,
        onReload: @escaping () -> Void,
        onConfigChanged: @escaping (PetConfig) -> PetConfig
    ) {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "\(AppBranding.displayName) — 偏好设置"
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        let view = PreferencesView(
            model: model,
            config: config,
            packManager: packManager,
            onDismiss: { [weak self] in self?.window?.orderOut(nil) },
            onReload: onReload,
            onConfigChanged: onConfigChanged
        )
        window?.contentView = NSHostingView(rootView: view)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
