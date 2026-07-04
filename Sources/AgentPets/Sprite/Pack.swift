import Foundation
import AppKit

/// Immutable description of a single sprite pack: metadata + frames loaded as `NSImage`s.
struct Pack: Sendable {
    /// Stable identifier — folder name (e.g. "claude-pixel"). Used for lookup / `pet.json.activePack`.
    let id: String
    /// Friendly display name from `pack.json` (e.g. "Orange Tabby"). For UI.
    let displayName: String
    let author: String
    let version: Int
    let frameSize: CGSize
    let defaultFallback: String
    let loop: [String: Bool]
    let folder: URL

    /// Keyed by sprite folder name (e.g. "idle", "working"). Values are ordered frames.
    let frames: [String: [NSImage]]

    /// Backwards-compat alias — older code referenced `name` for the display name.
    var name: String { displayName }

    static let placeholderName = "placeholder"

    /// Empty placeholder — used when no pack is loaded yet (so the UI can still render something).
    static let empty = Pack(
        id: placeholderName,
        displayName: "Loading…",
        author: "",
        version: 1,
        frameSize: CGSize(width: 28, height: 28),
        defaultFallback: "idle",
        loop: [:],
        folder: URL(fileURLWithPath: "/"),
        frames: [:]
    )

    /// Look up frames for a given state, with fallback chain: state → defaultFallback → first available.
    func images(forState state: PetState, mapName: String) -> [NSImage] {
        if let imgs = frames[mapName], !imgs.isEmpty { return imgs }
        if let imgs = frames[defaultFallback], !imgs.isEmpty { return imgs }
        // Last resort: any state with frames.
        for (_, imgs) in frames where !imgs.isEmpty { return imgs }
        return []
    }

    func loopEnabled(for mapName: String) -> Bool {
        loop[mapName] ?? true
    }
}

/// Raw `pack.json` schema for decoding. Falls back to defaults for missing keys.
struct PackManifest: Codable {
    var name: String
    var author: String?
    var version: Int?
    var frameSize: FrameSize?
    var states: [String]?
    var defaultFallback: String?
    var loop: [String: Bool]?

    struct FrameSize: Codable {
        var w: Double
        var h: Double
    }

    static let `default` = PackManifest(
        name: "Unnamed",
        author: nil,
        version: nil,
        frameSize: nil,
        states: nil,
        defaultFallback: nil,
        loop: nil
    )
}
