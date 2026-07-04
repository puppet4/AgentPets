import Foundation

final class AgentTaskRegistry {
    private struct TaskContext {
        var state: PetState
        var title: String?
        var termProgram: String?
        var cwd: String?
        var lastActivityAt: Date
    }

    private let now: () -> Date
    private let staleTaskTTL: TimeInterval
    private var latestProcessesByKey: [String: TerminalAgentProcessSnapshot] = [:]
    private var latestHostSessionsByTTY: [String: HostSessionInfo] = [:]
    private var contextsByKey: [String: TaskContext] = [:]
    private var tasksByKey: [String: AgentTaskSnapshot] = [:]

    init(
        now: @escaping () -> Date = Date.init,
        staleTaskTTL: TimeInterval = 12
    ) {
        self.now = now
        self.staleTaskTTL = staleTaskTTL
    }

    var tasks: [AgentTaskSnapshot] {
        Array(tasksByKey.values).sorted { lhs, rhs in
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
            if lhs.state.priority != rhs.state.priority {
                return lhs.state.priority > rhs.state.priority
            }
            if lhs.cpu != rhs.cpu {
                return lhs.cpu > rhs.cpu
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    func record(processSnapshot: TerminalAgentSnapshot, hostSessions: [HostSessionInfo]) {
        latestProcessesByKey = Dictionary(
            uniqueKeysWithValues: processSnapshot.processes.map { (Self.taskKey(tty: $0.tty, pid: $0.pid), $0) }
        )
        latestHostSessionsByTTY = hostSessions.reduce(into: [:]) { partialResult, session in
            guard !session.tty.isEmpty else { return }
            guard let current = partialResult[session.tty] else {
                partialResult[session.tty] = session
                return
            }

            partialResult[session.tty] = Self.preferredHostSession(current, session)
        }
        rebuild()
    }

    func record(event: HookEvent) {
        guard let meta = event.taskMeta else { return }
        let key = Self.taskKey(tty: meta.tty, pid: nil, sessionID: meta.termSessionID)
        let previous = contextsByKey[key]?.state ?? .idle
        let nextState = PetState.next(from: previous, on: event)
        contextsByKey[key] = TaskContext(
            state: nextState,
            title: meta.displayTitle,
            termProgram: meta.termProgram,
            cwd: meta.cwd,
            lastActivityAt: now()
        )
        rebuild()
    }

    private func rebuild() {
        let currentTime = now()
        contextsByKey = contextsByKey.filter { currentTime.timeIntervalSince($0.value.lastActivityAt) <= staleTaskTTL }

        var rebuilt: [String: AgentTaskSnapshot] = [:]

        for (key, process) in latestProcessesByKey {
            rebuilt[key] = buildTask(
                key: key,
                process: process,
                previous: tasksByKey[key]
            )
        }

        for (key, previous) in tasksByKey where rebuilt[key] == nil {
            guard let context = contextsByKey[key] else { continue }
            guard currentTime.timeIntervalSince(context.lastActivityAt) <= staleTaskTTL else { continue }

            rebuilt[key] = AgentTaskSnapshot(
                id: previous.id,
                agent: previous.agent,
                pid: previous.pid,
                ppid: previous.ppid,
                tty: previous.tty,
                cpu: previous.cpu,
                title: context.title ?? previous.title,
                state: context.state,
                lastActivityAt: context.lastActivityAt,
                host: previous.host,
                location: previous.location,
                activationCapability: previous.activationCapability,
                termProgram: context.termProgram ?? previous.termProgram,
                cwd: context.cwd ?? previous.cwd
            )
        }

        tasksByKey = rebuilt
    }

    private func buildTask(
        key: String,
        process: TerminalAgentProcessSnapshot,
        previous: AgentTaskSnapshot?
    ) -> AgentTaskSnapshot {
        let context = contextsByKey[key]
        let hostSession = process.tty.flatMap { latestHostSessionsByTTY[$0] }
        let host = hostSession?.host
            ?? TaskHostKind.from(termProgram: context?.termProgram, cwdHint: context?.cwd)

        let title = hostSession?.title
            ?? context?.title
            ?? defaultTitle(agent: process.agent, cwd: context?.cwd)

        let state = resolvedState(
            processState: process.suggestedState,
            context: context
        )

        let location: TaskLocation = hostSession?.location ?? {
            guard let bundleID = host.bundleID else { return .unavailable }
            return .window(bundleID: bundleID, title: title)
        }()

        let capability = hostSession?.activationCapability ?? {
            switch location {
            case .window:
                return .windowOnly
            case .unavailable:
                return .unavailable
            case .iTerm2:
                return .exact
            }
        }()

        let lastActivityAt: Date
        if let context {
            lastActivityAt = context.lastActivityAt
        } else if process.suggestedState.isWorking {
            lastActivityAt = now()
        } else {
            lastActivityAt = previous?.lastActivityAt ?? now()
        }

        return AgentTaskSnapshot(
            id: previous?.id ?? key,
            agent: process.agent,
            pid: process.pid,
            ppid: process.ppid,
            tty: process.tty,
            cpu: process.cpu,
            title: title,
            state: state,
            lastActivityAt: lastActivityAt,
            host: host,
            location: location,
            activationCapability: capability,
            termProgram: context?.termProgram,
            cwd: context?.cwd
        )
    }

    private func resolvedState(
        processState: PetState,
        context: TaskContext?
    ) -> PetState {
        guard let context else { return processState }
        let age = now().timeIntervalSince(context.lastActivityAt)
        if age <= holdDuration(for: context.state) {
            return context.state
        }
        return processState
    }

    private func holdDuration(for state: PetState) -> TimeInterval {
        switch state {
        case .success, .error:
            return 4
        case .thinking, .compacting:
            return 3
        case .working, .searching, .editing, .running, .reading:
            return 2
        case .listening:
            return 3
        case .idle, .offline:
            return 1
        }
    }

    private func defaultTitle(agent: TerminalAgent, cwd: String?) -> String {
        if let cwd, !cwd.isEmpty {
            return URL(fileURLWithPath: cwd).lastPathComponent + " (\(agent.rawValue))"
        }
        return agent.rawValue.capitalized
    }

    static func taskKey(tty: String?, pid: Int?, sessionID: String? = nil) -> String {
        if let tty, !tty.isEmpty {
            return "tty:\(tty)"
        }
        if let sessionID, !sessionID.isEmpty {
            return "session:\(sessionID)"
        }
        if let pid {
            return "pid:\(pid)"
        }
        return "unknown"
    }

    private static func preferredHostSession(_ lhs: HostSessionInfo, _ rhs: HostSessionInfo) -> HostSessionInfo {
        if lhs.activationCapability != rhs.activationCapability {
            return lhs.activationCapability == .exact ? lhs : rhs
        }
        if lhs.title.isEmpty != rhs.title.isEmpty {
            return lhs.title.isEmpty ? rhs : lhs
        }
        return lhs
    }
}
