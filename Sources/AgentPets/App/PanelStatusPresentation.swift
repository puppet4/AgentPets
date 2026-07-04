import SwiftUI

struct PanelStatusPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let badgeText: String
    let symbolName: String
    let accent: PanelAccent

    var accessibilityLabel: String {
        "\(AppBranding.displayName)，\(title)，\(detail)"
    }

    static func `for`(_ state: PetState) -> PanelStatusPresentation {
        switch state {
        case .idle:
            return PanelStatusPresentation(
                title: "待机",
                detail: "随时待命",
                badgeText: "待命中",
                symbolName: "moon.stars.fill",
                accent: .aqua
            )
        case .listening:
            return PanelStatusPresentation(
                title: "等待输入",
                detail: "检测到 Claude 或 Codex",
                badgeText: "等输入",
                symbolName: "waveform",
                accent: .blue
            )
        case .thinking:
            return PanelStatusPresentation(
                title: "思考中",
                detail: "整理下一步",
                badgeText: "思考中",
                symbolName: "sparkles",
                accent: .violet
            )
        case .working:
            return PanelStatusPresentation(
                title: "工作中",
                detail: "正在处理任务",
                badgeText: "工作中",
                symbolName: "bolt.fill",
                accent: .amber
            )
        case .searching:
            return PanelStatusPresentation(
                title: "搜索中",
                detail: "正在查找线索",
                badgeText: "查资料",
                symbolName: "magnifyingglass",
                accent: .blue
            )
        case .editing:
            return PanelStatusPresentation(
                title: "编辑中",
                detail: "正在修改文件",
                badgeText: "改文件",
                symbolName: "pencil",
                accent: .green
            )
        case .running:
            return PanelStatusPresentation(
                title: "运行中",
                detail: "正在执行命令",
                badgeText: "跑命令",
                symbolName: "terminal.fill",
                accent: .amber
            )
        case .reading:
            return PanelStatusPresentation(
                title: "读取中",
                detail: "正在看代码",
                badgeText: "读代码",
                symbolName: "doc.text.magnifyingglass",
                accent: .blue
            )
        case .success:
            return PanelStatusPresentation(
                title: "完成",
                detail: "任务已收尾",
                badgeText: "完成啦",
                symbolName: "checkmark.circle.fill",
                accent: .green
            )
        case .error:
            return PanelStatusPresentation(
                title: "出错",
                detail: "需要看一下",
                badgeText: "出错了",
                symbolName: "exclamationmark.triangle.fill",
                accent: .red
            )
        case .compacting:
            return PanelStatusPresentation(
                title: "压缩中",
                detail: "整理上下文",
                badgeText: "压缩中",
                symbolName: "arrow.triangle.2.circlepath",
                accent: .violet
            )
        case .offline:
            return PanelStatusPresentation(
                title: "离线",
                detail: "等待 Claude 或 Codex",
                badgeText: "休息中",
                symbolName: "moon.zzz.fill",
                accent: .gray
            )
        }
    }
}

enum PanelAccent: String, Equatable, Sendable {
    case aqua
    case blue
    case violet
    case amber
    case green
    case red
    case gray

    var color: Color {
        switch self {
        case .aqua:   return Color(red: 0.24, green: 0.82, blue: 0.76)
        case .blue:   return Color(red: 0.28, green: 0.58, blue: 0.96)
        case .violet: return Color(red: 0.60, green: 0.43, blue: 0.96)
        case .amber:  return Color(red: 0.96, green: 0.68, blue: 0.25)
        case .green:  return Color(red: 0.25, green: 0.74, blue: 0.42)
        case .red:    return Color(red: 0.95, green: 0.30, blue: 0.31)
        case .gray:   return Color(red: 0.56, green: 0.61, blue: 0.67)
        }
    }
}
