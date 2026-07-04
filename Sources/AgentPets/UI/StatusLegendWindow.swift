import SwiftUI
import AppKit

struct StatusLegendEntry: Identifiable, Equatable, Sendable {
    let state: PetState
    let trigger: String
    let behavior: String

    var id: String { state.rawValue }
    var presentation: PanelStatusPresentation { .for(state) }

    static let all: [StatusLegendEntry] = [
        StatusLegendEntry(
            state: .offline,
            trigger: "SessionEnd，或没有检测到 claude/codex 进程",
            behavior: "进入休息姿态，状态气泡变灰"
        ),
        StatusLegendEntry(
            state: .idle,
            trigger: "SessionStart，或任务完成后的自动回落",
            behavior: "轻微呼吸，表示随时待命"
        ),
        StatusLegendEntry(
            state: .listening,
            trigger: "UserPromptSubmit、Notification，或检测到 claude/codex 低 CPU 存活",
            behavior: "耳朵更警觉，等待下一步输入或授权"
        ),
        StatusLegendEntry(
            state: .thinking,
            trigger: "PostToolUse 后的短暂停顿",
            behavior: "轻微歪头，表示模型在整理下一步"
        ),
        StatusLegendEntry(
            state: .working,
            trigger: "PreToolUse 的兜底状态，或终端 claude/codex CPU >= 2%",
            behavior: "更快弹动，表示正在处理任务"
        ),
        StatusLegendEntry(
            state: .reading,
            trigger: "PreToolUse: Read",
            behavior: "归入工作动画，状态气泡显示读取图标"
        ),
        StatusLegendEntry(
            state: .searching,
            trigger: "PreToolUse: Grep、Glob、WebSearch、WebFetch",
            behavior: "归入工作动画，状态气泡显示搜索图标"
        ),
        StatusLegendEntry(
            state: .editing,
            trigger: "PreToolUse: Edit、Write、NotebookEdit",
            behavior: "归入工作动画，状态气泡显示编辑图标"
        ),
        StatusLegendEntry(
            state: .running,
            trigger: "PreToolUse: Bash",
            behavior: "归入工作动画，状态气泡显示终端图标"
        ),
        StatusLegendEntry(
            state: .compacting,
            trigger: "PreCompact",
            behavior: "上下文压缩中，优先级高于普通工作态"
        ),
        StatusLegendEntry(
            state: .success,
            trigger: "Stop",
            behavior: "短暂开心，然后回到待机"
        ),
        StatusLegendEntry(
            state: .error,
            trigger: "PostToolUseFailure",
            behavior: "短暂错误提示，然后回到待机"
        )
    ]
}

struct StatusLegendView: View {
    private let entries = StatusLegendEntry.all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("状态说明")
                .font(.title2.bold())

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(entries) { entry in
                        StatusLegendRow(entry: entry)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
        .frame(width: 620, height: 560)
    }
}

private struct StatusLegendRow: View {
    let entry: StatusLegendEntry

    var body: some View {
        let presentation = entry.presentation

        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(presentation.accent.color.opacity(0.14))
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(presentation.accent.color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(presentation.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(entry.state.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(entry.trigger)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.behavior)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@MainActor
final class StatusLegendWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "\(AppBranding.displayName) — 状态说明"
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        window?.contentView = NSHostingView(rootView: StatusLegendView())
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
