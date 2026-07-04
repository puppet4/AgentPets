import Foundation

enum TaskHostKind: String, Equatable, Sendable {
    case iTerm2
    case terminal
    case warp
    case vscode
    case jetbrains
    case unknown

    var displayName: String {
        switch self {
        case .iTerm2: return "iTerm2"
        case .terminal: return "Terminal"
        case .warp: return "Warp"
        case .vscode: return "VSCode"
        case .jetbrains: return "JetBrains"
        case .unknown: return "Unknown"
        }
    }

    var bundleID: String? {
        switch self {
        case .iTerm2: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .warp: return "com.pbatards.Warp"
        case .vscode: return "com.microsoft.VSCode"
        case .jetbrains: return nil
        case .unknown: return nil
        }
    }

    static func from(termProgram: String?, cwdHint: String? = nil) -> TaskHostKind {
        let normalized = (termProgram ?? "").lowercased()
        if normalized.contains("iterm") {
            return .iTerm2
        }
        if normalized.contains("apple_terminal") || normalized.contains("terminal") {
            return .terminal
        }
        if normalized.contains("warp") {
            return .warp
        }
        if normalized.contains("vscode") {
            return .vscode
        }
        let cwd = (cwdHint ?? "").lowercased()
        if cwd.contains("/jetbrains") || cwd.contains("/idea") {
            return .jetbrains
        }
        return .unknown
    }
}

enum TaskActivationCapability: String, Equatable, Sendable {
    case exact
    case windowOnly
    case unavailable
}

enum TaskLocation: Equatable, Sendable {
    case iTerm2(windowID: Int, tabIndex: Int, tty: String)
    case window(bundleID: String, title: String?)
    case unavailable
}

struct HostSessionInfo: Equatable, Sendable {
    let host: TaskHostKind
    let tty: String
    let title: String
    let location: TaskLocation
    let activationCapability: TaskActivationCapability
}

struct AgentTaskSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let agent: TerminalAgent
    let pid: Int
    let ppid: Int
    let tty: String?
    let cpu: Double
    let title: String
    let state: PetState
    let lastActivityAt: Date
    let host: TaskHostKind
    let location: TaskLocation
    let activationCapability: TaskActivationCapability
    let termProgram: String?
    let cwd: String?

    var hostDisplayName: String { host.displayName }

    static func sorted(_ tasks: [AgentTaskSnapshot]) -> [AgentTaskSnapshot] {
        tasks.sorted { lhs, rhs in
            if lhs.state.priority != rhs.state.priority {
                return lhs.state.priority > rhs.state.priority
            }
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
            if lhs.cpu != rhs.cpu {
                return lhs.cpu > rhs.cpu
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    static func aggregate(from tasks: [AgentTaskSnapshot]) -> AgentTaskSnapshot? {
        sorted(tasks).first
    }
}

#if DEBUG
extension AgentTaskSnapshot {
    static func stub(
        id: String = UUID().uuidString,
        agent: TerminalAgent = .codex,
        pid: Int = 1,
        ppid: Int = 0,
        tty: String? = "ttys000",
        cpu: Double = 0,
        title: String = "Task",
        state: PetState = .listening,
        lastActivityAt: Date = .distantPast,
        host: TaskHostKind = .iTerm2,
        location: TaskLocation = .unavailable,
        activationCapability: TaskActivationCapability = .unavailable,
        termProgram: String? = "iTerm.app",
        cwd: String? = "/Users/kangjialv/Desktop"
    ) -> AgentTaskSnapshot {
        AgentTaskSnapshot(
            id: id,
            agent: agent,
            pid: pid,
            ppid: ppid,
            tty: tty,
            cpu: cpu,
            title: title,
            state: state,
            lastActivityAt: lastActivityAt,
            host: host,
            location: location,
            activationCapability: activationCapability,
            termProgram: termProgram,
            cwd: cwd
        )
    }
}
#endif
