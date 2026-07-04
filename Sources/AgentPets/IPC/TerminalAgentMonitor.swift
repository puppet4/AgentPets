import Foundation

enum TerminalAgent: String, Equatable, Sendable {
    case claude
    case codex
}

struct TerminalAgentProcessSnapshot: Equatable, Sendable {
    let pid: Int
    let ppid: Int
    let tty: String?
    let agent: TerminalAgent
    let cpu: Double

    var suggestedState: PetState {
        cpu >= 2.0 ? .working : .listening
    }
}

struct TerminalAgentSnapshot: Equatable, Sendable {
    let processes: [TerminalAgentProcessSnapshot]
    let primaryProcess: TerminalAgentProcessSnapshot?
    let primaryAgent: TerminalAgent?
    let suggestedState: PetState
    let activeProcessCount: Int

    static let inactive = TerminalAgentSnapshot(
        processes: [],
        primaryProcess: nil,
        primaryAgent: nil,
        suggestedState: .idle,
        activeProcessCount: 0
    )

    static func parse(psOutput: String) -> TerminalAgentSnapshot {
        let rows = psOutput
            .split(whereSeparator: \.isNewline)
            .compactMap(TerminalAgentProcessSnapshot.parse)

        guard !rows.isEmpty else { return .inactive }

        let primary = rows.sorted { lhs, rhs in
            if lhs.agent != rhs.agent {
                return lhs.agent == .codex
            }
            return lhs.cpu > rhs.cpu
        }.first

        return TerminalAgentSnapshot(
            processes: rows,
            primaryProcess: primary,
            primaryAgent: primary?.agent,
            suggestedState: primary?.suggestedState ?? .idle,
            activeProcessCount: rows.count
        )
    }
}

private extension TerminalAgentProcessSnapshot {
    static func parse(_ line: Substring) -> TerminalAgentProcessSnapshot? {
        let raw = String(line)
        if raw.hasPrefix("PID ") || raw.hasPrefix("USER ") { return nil }

        let parts = raw.split(separator: " ", maxSplits: 6, omittingEmptySubsequences: true)
        guard parts.count >= 6 else { return nil }

        let pidToken = String(parts[0])
        let ppidToken = String(parts[1])
        let ttyToken = String(parts[2])
        let cpuToken = String(parts[4])
        let comm = String(parts[5]).lowercased()
        let args = parts.count >= 7 ? String(parts[6]).lowercased() : ""
        guard let pid = Int(pidToken), let ppid = Int(ppidToken) else { return nil }
        guard let cpu = Double(cpuToken) else { return nil }
        guard ttyToken != "??" else { return nil }

        if isAgent(comm: comm, args: args, name: "codex") {
            return TerminalAgentProcessSnapshot(
                pid: pid,
                ppid: ppid,
                tty: ttyToken,
                agent: .codex,
                cpu: cpu
            )
        }
        if isAgent(comm: comm, args: args, name: "claude") {
            return TerminalAgentProcessSnapshot(
                pid: pid,
                ppid: ppid,
                tty: ttyToken,
                agent: .claude,
                cpu: cpu
            )
        }
        return nil
    }

    private static func isAgent(comm: String, args: String, name: String) -> Bool {
        if comm == name { return true }
        if comm.hasSuffix("/\(name)") { return true }
        if args == name { return true }
        if args.hasPrefix("\(name) ") { return true }
        if args.contains("/\(name) ") { return true }
        return false
    }
}

@MainActor
final class TerminalAgentMonitor {
    private let onSnapshot: (TerminalAgentSnapshot) -> Void
    private let psOutputProvider: () -> String
    private var timer: Timer?
    private var lastSnapshot = TerminalAgentSnapshot.inactive

    init(
        psOutputProvider: @escaping () -> String = TerminalAgentMonitor.runPS,
        onSnapshot: @escaping (TerminalAgentSnapshot) -> Void
    ) {
        self.psOutputProvider = psOutputProvider
        self.onSnapshot = onSnapshot
    }

    func start() {
        stop()
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let output = psOutputProvider()
        let snapshot = TerminalAgentSnapshot.parse(psOutput: output)
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        onSnapshot(snapshot)
    }

    nonisolated private static func runPS() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid,ppid,tty,stat,pcpu,comm,args"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
