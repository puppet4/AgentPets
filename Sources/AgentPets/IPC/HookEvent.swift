import Foundation

/// Payload received from the `pet-notify.sh` inbox file. Mirrors the
/// `hook_event_name` plus a curated subset of useful fields. Unknown fields
/// are tolerated via `JSONDecoder` defaults.
struct HookEvent: Codable, Sendable {
    let kind: String            // hook_event_name
    let tool: String?
    let file: String?
    let cmd: String?
    let prompt: String?
    let stop: String?
    let error: String?
    let source: String?
    let reason: String?
    let ts: Double?
    let taskMeta: TaskMeta?

    struct TaskMeta: Codable, Equatable, Sendable {
        let termProgram: String?
        let termSessionID: String?
        let iTermSessionID: String?
        let tty: String?
        let cwd: String?

        var displayTitle: String? {
            guard let cwd, !cwd.isEmpty else { return nil }
            let name = URL(fileURLWithPath: cwd).lastPathComponent
            return name.isEmpty ? nil : name
        }
    }

    /// Decodes from the raw Claude Code stdin JSON, picking the relevant bits.
    static func decode(from data: Data) -> HookEvent? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let toolInput = raw["tool_input"] as? [String: Any]
        let taskMeta: TaskMeta?
        if let taskRaw = raw["task_meta"] as? [String: Any] {
            taskMeta = TaskMeta(
                termProgram: taskRaw["term_program"] as? String,
                termSessionID: taskRaw["term_session_id"] as? String,
                iTermSessionID: taskRaw["iterm_session_id"] as? String,
                tty: taskRaw["tty"] as? String,
                cwd: taskRaw["cwd"] as? String
            )
        } else {
            taskMeta = nil
        }
        return HookEvent(
            kind: raw["hook_event_name"] as? String ?? "unknown",
            tool: raw["tool_name"] as? String,
            file: toolInput?["file_path"] as? String,
            cmd: toolInput?["command"] as? String,
            prompt: raw["prompt"] as? String,
            stop: raw["stop_reason"] as? String,
            error: (raw["error"] as? String) ?? ((raw["tool_response"] as? String).flatMap { $0.isEmpty ? nil : $0 }),
            source: raw["source"] as? String,
            reason: raw["reason"] as? String,
            ts: raw["ts"] as? Double,
            taskMeta: taskMeta
        )
    }

    /// Short label suitable for the Touch Bar sub-label area.
    var shortLabel: String? {
        switch kind {
        case "PreToolUse":
            if let tool = tool {
                if let file = file { return "\(tool) \(displayName(file))" }
                if let cmd = cmd { return "\(tool) \(truncate(cmd, to: 24))" }
                return tool
            }
        case "PostToolUse":
            if let tool = tool { return "\(tool) ✓" }
        case "PostToolUseFailure":
            if let tool = tool, let error = error {
                return "\(tool) failed: \(truncate(error, to: 20))"
            }
        case "Notification":
            return "needs permission"
        case "UserPromptSubmit":
            if let prompt = prompt { return truncate(prompt, to: 24) }
        case "Stop":
            return "done"
        case "PreCompact":
            return "compacting…"
        case "SessionEnd":
            return "offline"
        default:
            break
        }
        return nil
    }

    private func displayName(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    private func truncate(_ s: String, to n: Int) -> String {
        if s.count <= n { return s }
        return String(s.prefix(n - 1)) + "…"
    }
}
