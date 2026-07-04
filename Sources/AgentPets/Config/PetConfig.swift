import Foundation

/// User-editable configuration. Loaded from `~/Library/Application Support/AgentPets/pet.json`.
/// All fields have sensible defaults; missing keys → defaults applied.
struct PetConfig: Codable, Equatable, Sendable {
    var version: Int
    var activePack: String
    var followActiveAgent: Bool
    var packsDir: String
    var fps: Double
    var showLabel: Bool
    var labelMaxChars: Int
    var autoForeground: Bool
    var minStateDurationMs: Int
    var successHoldSeconds: Double
    var errorHoldSeconds: Double
    var foregroundOnEvents: [String]
    var stateSpriteMap: [String: String]
    var stateLabelPolicy: StateLabelPolicy
    /// UI language: "zh" (Chinese) or "en" (English).
    var language: String

    struct StateLabelPolicy: Codable, Equatable, Sendable {
        var showOn: [String]
    }

    init(
        version: Int,
        activePack: String,
        followActiveAgent: Bool,
        packsDir: String,
        fps: Double,
        showLabel: Bool,
        labelMaxChars: Int,
        autoForeground: Bool,
        minStateDurationMs: Int,
        successHoldSeconds: Double,
        errorHoldSeconds: Double,
        foregroundOnEvents: [String],
        stateSpriteMap: [String: String],
        stateLabelPolicy: StateLabelPolicy,
        language: String
    ) {
        self.version = version
        self.activePack = activePack
        self.followActiveAgent = followActiveAgent
        self.packsDir = packsDir
        self.fps = fps
        self.showLabel = showLabel
        self.labelMaxChars = labelMaxChars
        self.autoForeground = autoForeground
        self.minStateDurationMs = minStateDurationMs
        self.successHoldSeconds = successHoldSeconds
        self.errorHoldSeconds = errorHoldSeconds
        self.foregroundOnEvents = foregroundOnEvents
        self.stateSpriteMap = stateSpriteMap
        self.stateLabelPolicy = stateLabelPolicy
        self.language = language
    }

    static let `default` = PetConfig(
        version: 1,
        activePack: BundledPetPackRenderer.defaultPackID,
        followActiveAgent: true,
        packsDir: "~/Library/Application Support/AgentPets/packs",
        fps: 12,
        showLabel: true,
        labelMaxChars: 24,
        autoForeground: true,
        minStateDurationMs: 300,
        successHoldSeconds: 3,
        errorHoldSeconds: 4,
        foregroundOnEvents: [
            "SessionStart",
            "UserPromptSubmit",
            "Notification",
            "PreCompact"
        ],
        stateSpriteMap: [
            "idle":       "idle",
            "listening":  "listening",
            "thinking":   "thinking",
            "working":    "working",
            "searching":  "working",
            "editing":    "working",
            "running":    "working",
            "reading":    "working",
            "success":    "success",
            "error":      "error",
            "compacting": "compacting",
            "offline":    "offline"
        ],
        stateLabelPolicy: StateLabelPolicy(
            showOn: ["working", "thinking", "error", "searching", "editing", "running", "reading"]
        ),
        language: "zh"
    )

    enum CodingKeys: String, CodingKey {
        case version
        case activePack
        case followActiveAgent
        case packsDir
        case fps
        case showLabel
        case labelMaxChars
        case autoForeground
        case minStateDurationMs
        case successHoldSeconds
        case errorHoldSeconds
        case foregroundOnEvents
        case stateSpriteMap
        case stateLabelPolicy
        case language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PetConfig.default

        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? defaults.version
        activePack = try container.decodeIfPresent(String.self, forKey: .activePack) ?? defaults.activePack
        followActiveAgent = try container.decodeIfPresent(Bool.self, forKey: .followActiveAgent) ?? true
        packsDir = try container.decodeIfPresent(String.self, forKey: .packsDir) ?? defaults.packsDir
        fps = try container.decodeIfPresent(Double.self, forKey: .fps) ?? defaults.fps
        showLabel = try container.decodeIfPresent(Bool.self, forKey: .showLabel) ?? defaults.showLabel
        labelMaxChars = try container.decodeIfPresent(Int.self, forKey: .labelMaxChars) ?? defaults.labelMaxChars
        autoForeground = try container.decodeIfPresent(Bool.self, forKey: .autoForeground) ?? defaults.autoForeground
        minStateDurationMs = try container.decodeIfPresent(Int.self, forKey: .minStateDurationMs) ?? defaults.minStateDurationMs
        successHoldSeconds = try container.decodeIfPresent(Double.self, forKey: .successHoldSeconds) ?? defaults.successHoldSeconds
        errorHoldSeconds = try container.decodeIfPresent(Double.self, forKey: .errorHoldSeconds) ?? defaults.errorHoldSeconds
        foregroundOnEvents = try container.decodeIfPresent([String].self, forKey: .foregroundOnEvents) ?? defaults.foregroundOnEvents
        stateSpriteMap = try container.decodeIfPresent([String: String].self, forKey: .stateSpriteMap) ?? defaults.stateSpriteMap
        stateLabelPolicy = try container.decodeIfPresent(StateLabelPolicy.self, forKey: .stateLabelPolicy) ?? defaults.stateLabelPolicy
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? defaults.language
    }

    /// Load from disk; create default file if missing.
    static func load(from url: URL) -> PetConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let cfg = `default`
            try? cfg.write(to: url)
            return cfg
        }
        do {
            let data = try Data(contentsOf: url)
            let cfg = try JSONDecoder().decode(PetConfig.self, from: data)
            return cfg
        } catch {
            NSLog("[PetConfig] failed to decode \(url.path): \(error). Using defaults.")
            return `default`
        }
    }

    /// Write to disk as pretty-printed JSON.
    func write(to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(self)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    /// Resolve `packsDir` with `~` expansion.
    func resolvedPacksDir() -> URL {
        let expanded = (packsDir as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    /// Map a PetState → sprite folder name (via `stateSpriteMap`).
    func spriteName(for state: PetState) -> String {
        stateSpriteMap[state.rawValue] ?? state.rawValue
    }

    func shouldShowLabel(for state: PetState) -> Bool {
        stateLabelPolicy.showOn.contains(state.rawValue)
    }
}
