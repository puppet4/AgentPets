import Foundation
import AppKit

/// Central observable state for the pet. Drives SwiftUI, holds debounce timers,
/// and arbitrates state transitions.
@MainActor
@Observable
final class PetModel {
    // Observable state
    var state: PetState = .offline
    var tasks: [AgentTaskSnapshot] = []
    var subLabel: String?
    var lastError: String?
    var lastEventAt: Date = .distantPast

    // Config-derived (synced from PetConfig)
    var fps: Double = 12
    var showLabel: Bool = true
    var autoForeground: Bool = true
    var minStateDuration: TimeInterval = 0.3
    var successHoldSeconds: Double = 3
    var errorHoldSeconds: Double = 4
    var foregroundOnEvents: Set<String> = []

    // Internal
    private var burstWindow: [Date] = []
    private var lastTransition: Date = .distantPast
    private var downgradeTask: Task<Void, Never>?
    private var labelThrottle: Date = .distantPast

    /// Apply user config in place. Called on pet.json hot-reload.
    func apply(_ config: PetConfig) {
        self.fps = config.fps
        self.showLabel = config.showLabel
        self.autoForeground = config.autoForeground
        self.minStateDuration = TimeInterval(config.minStateDurationMs) / 1000.0
        self.successHoldSeconds = config.successHoldSeconds
        self.errorHoldSeconds = config.errorHoldSeconds
        self.foregroundOnEvents = Set(config.foregroundOnEvents)
    }

    /// Process an inbound hook event. Decides next state with debounce.
    func handle(event: HookEvent, config: PetConfig, appDelegate: AppDelegate? = nil) {
        lastEventAt = .now

        // Sub-label with throttling
        if let label = event.shortLabel {
            let now = Date()
            if now.timeIntervalSince(labelThrottle) > 0.25 || subLabel == nil {
                subLabel = label
                labelThrottle = now
            }
        }
        if let err = event.error { lastError = err }

        // Burst tracking
        let now = Date()
        burstWindow = burstWindow.filter { now.timeIntervalSince($0) < 1.0 }
        burstWindow.append(now)

        let next = PetState.next(from: state, on: event)
        let held: PetState = {
            if burstWindow.count >= 3 && state.isWorking && next == .thinking {
                return state
            }
            return next
        }()

        // Minimum-state-duration guard
        let elapsed = now.timeIntervalSince(lastTransition)
        if held != state && elapsed < minStateDuration {
            return
        }
        transition(to: held)

        // Auto-foreground policy
        if autoForeground,
           foregroundOnEvents.contains(event.kind),
           let app = appDelegate {
            NSApp.activate(ignoringOtherApps: true)
            _ = app
        }

        // Downgrade timers
        switch event.kind {
        case "Stop":
            scheduleDowngrade(after: successHoldSeconds) { [weak self] in
                self?.transition(to: .idle)
            }
        case "PostToolUseFailure":
            scheduleDowngrade(after: errorHoldSeconds) { [weak self] in
                self?.transition(to: .idle)
            }
        default:
            break
        }
    }

    private func transition(to new: PetState) {
        guard new != state else { return }
        state = new
        lastTransition = Date()
    }

    func setState(_ new: PetState) {
        transition(to: new)
        lastEventAt = .now
    }

    private func scheduleDowngrade(after seconds: Double, action: @escaping () -> Void) {
        downgradeTask?.cancel()
        downgradeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}

extension PetState {
    /// Pure mapping function: given current state + event, what state should we transition to?
    static func next(from current: PetState, on event: HookEvent) -> PetState {
        switch event.kind {
        case "SessionStart":
            // Don't override offline→idle: stay close to what the user expects.
            return .idle

        case "UserPromptSubmit":
            return .listening

        case "PreToolUse":
            switch event.tool {
            case "Read":                return .reading
            case "Edit", "Write", "NotebookEdit": return .editing
            case "Bash":                return .running
            case "Grep", "Glob", "WebSearch", "WebFetch": return .searching
            default:                    return .working
            }

        case "PostToolUse":
            // After a tool, we typically enter a brief "thinking" before next tool.
            // Burst logic in PetModel will hold working if many tools fire fast.
            return .thinking

        case "PostToolUseFailure":
            return .error

        case "Notification":
            return .listening

        case "Stop":
            return .success

        case "PreCompact":
            return .compacting

        case "SessionEnd":
            return .offline

        case "SubagentStop":
            return current

        default:
            return current
        }
    }
}
