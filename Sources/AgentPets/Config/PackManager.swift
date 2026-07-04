import Foundation
import AppKit

/// Discovers, loads, and hot-reloads sprite packs. Owns the active pack reference
/// that the SwiftUI layer reads.
@MainActor
final class PackManager {
    private(set) var packs: [Pack] = []
    private(set) var activePack: Pack?
    var productPacks: [Pack] {
        let supported = packs.filter { AgentPackCoordinator.isProductPack($0.id) }
        if !supported.isEmpty { return supported }
        if let placeholder = packs.first(where: { $0.id == Pack.placeholderName }) {
            return [placeholder]
        }
        return packs
    }

    let packsDir: URL
    private let loader = SpriteLoader()
    private var hotWatcher: HotReloadWatcher?

    /// Called whenever the pack list or active pack changes (hot reload).
    var onChange: (() -> Void)?

    init(packsDir: URL) {
        self.packsDir = packsDir
    }

    /// Initial discovery + load of the active pack.
    func bootstrap(activeName: String) async {
        await discoverPacks()
        await loadActivePack(named: activeName)
        startHotReload()
    }

    /// Reload everything from disk (called on hot-reload signal).
    func reloadAll(activeName: String) async {
        let previousActive = activePack?.id ?? activeName
        await discoverPacks()
        await loadActivePack(named: previousActive)
        onChange?()
    }

    /// Switch to a different pack by name.
    func switchPack(to name: String) async {
        await loadActivePack(named: name)
        startHotReload()    // re-bind watcher to new active folder
        onChange?()
    }

    // MARK: - Internals

    private func discoverPacks() async {
        let fm = FileManager.default
        try? fm.createDirectory(at: packsDir, withIntermediateDirectories: true)

        var found: [Pack] = []
        if let items = try? fm.contentsOfDirectory(
            at: packsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for dir in items {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: dir.path, isDirectory: &isDir)
                guard isDir.boolValue else { continue }
                if let pack = await loadOne(at: dir) {
                    found.append(pack)
                }
            }
        }

        // Placeholder if no packs exist
        if found.isEmpty {
            if let placeholder = await ensurePlaceholderExists() {
                found.append(placeholder)
            }
        }

        found.sort { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
        self.packs = found
    }

    private func loadOne(at folder: URL) async -> Pack? {
        let manifestURL = folder.appendingPathComponent("pack.json")
        let manifest: PackManifest
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? JSONDecoder().decode(PackManifest.self, from: data) {
            manifest = decoded
        } else {
            // Synthesize from folder name
            manifest = PackManifest(
                name: folder.lastPathComponent,
                author: nil,
                version: nil,
                frameSize: nil,
                states: nil,
                defaultFallback: nil,
                loop: nil
            )
        }
        let loaded = await loader.loadPack(folder: folder, manifest: manifest)
        guard !loaded.frames.isEmpty else { return nil }
        // Override `id` with the folder name so it's stable across pack.json edits.
        return Pack(
            id: folder.lastPathComponent,
            displayName: loaded.displayName,
            author: loaded.author,
            version: loaded.version,
            frameSize: loaded.frameSize,
            defaultFallback: loaded.defaultFallback,
            loop: loaded.loop,
            folder: loaded.folder,
            frames: loaded.frames
        )
    }

    private func loadActivePack(named name: String) async {
        if let match = productPacks.first(where: { $0.id == name }) {
            self.activePack = match
            return
        }
        // Try placeholder
        if let ph = packs.first(where: { $0.id == Pack.placeholderName }) {
            self.activePack = ph
            return
        }
        self.activePack = packs.first
    }

    private func startHotReload() {
        hotWatcher?.stop()
        var dirs: [URL] = [packsDir]
        if let active = activePack {
            dirs.append(active.folder)
        }
        hotWatcher = HotReloadWatcher(urls: dirs) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.reloadAll(activeName: self.activePack?.id ?? Pack.placeholderName)
            }
        }
        hotWatcher?.start()
    }

    // MARK: - Placeholder generation

    /// Creates a minimal placeholder pack on first run so the UI is never empty.
    private func ensurePlaceholderExists() async -> Pack? {
        let folder = packsDir.appendingPathComponent(Pack.placeholderName)
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let manifest = PackManifest(
            name: "Placeholder",
            author: "AgentPets",
            version: 1,
            frameSize: PackManifest.FrameSize(w: 28, h: 28),
            states: ["idle", "listening", "thinking", "working", "success", "error", "offline"],
            defaultFallback: "idle",
            loop: [
                "idle": true,
                "listening": true,
                "thinking": true,
                "working": true,
                "success": false,
                "error": false,
                "offline": true
            ]
        )
        let manifestData = (try? JSONEncoder().encode(manifest)) ?? Data()
        try? manifestData.write(to: folder.appendingPathComponent("pack.json"))

        // Generate simple PNG frames for each state
        let states: [(String, [NSColor])] = [
            ("idle",       [.systemGray]),
            ("listening",  [.systemBlue]),
            ("thinking",   [.systemPurple]),
            ("working",    [.systemOrange]),
            ("success",    [.systemGreen]),
            ("error",      [.systemRed]),
            ("offline",    [NSColor(white: 0.55, alpha: 1.0)])
        ]
        for (state, palette) in states {
            let dir = folder.appendingPathComponent(state)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let frames = PlaceholderRenderer.renderFrames(
                state: state,
                palette: palette,
                size: CGSize(width: 28, height: 28),
                count: state == "offline" ? 1 : 4
            )
            for (i, img) in frames.enumerated() {
                let url = dir.appendingPathComponent(String(format: "%02d.png", i))
                if let data = PlaceholderRenderer.pngData(from: img) {
                    try? data.write(to: url)
                }
            }
        }

        return await loadOne(at: folder)
    }
}
