import Foundation
import AppKit

/// Loads sprite PNGs from a pack folder into `[spriteName: [NSImage]]`.
/// Decoding happens on a background actor; callers get immutable values.
actor SpriteLoader {
    /// Returns a fully loaded `Pack`. Failures degrade gracefully: missing
    /// state folders → fallback chain (see `Pack.images(forState:mapName:)`).
    func loadPack(folder: URL, manifest: PackManifest) -> Pack {
        let manifest = mergeManifest(manifest)

        var frames: [String: [NSImage]] = [:]
        let candidates = subdirectories(of: folder)

        for sub in candidates {
            let name = sub.lastPathComponent
            let imgs = loadFrames(from: sub)
            if !imgs.isEmpty {
                frames[name] = imgs
            }
        }

        return Pack(
            id: manifest.name,
            displayName: manifest.name,
            author: manifest.author ?? "",
            version: manifest.version ?? 1,
            frameSize: CGSize(
                width: manifest.frameSize?.w ?? 28,
                height: manifest.frameSize?.h ?? 28
            ),
            defaultFallback: manifest.defaultFallback ?? "idle",
            loop: manifest.loop ?? [:],
            folder: folder,
            frames: frames
        )
    }

    // MARK: - Internals

    private func mergeManifest(_ m: PackManifest) -> PackManifest {
        var copy = m
        if copy.version == nil { copy.version = 1 }
        if copy.frameSize == nil {
            copy.frameSize = PackManifest.FrameSize(w: 28, h: 28)
        }
        if (copy.defaultFallback ?? "").isEmpty {
            copy.defaultFallback = "idle"
        }
        return copy
    }

    private func subdirectories(of folder: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items.filter { url in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            return isDir.boolValue
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func loadFrames(from dir: URL) -> [NSImage] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let pngs = items
            .filter { ["png", "PNG"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        var out: [NSImage] = []
        out.reserveCapacity(pngs.count)
        for url in pngs {
            if let img = NSImage(contentsOf: url), img.size.width > 0 {
                out.append(img)
            }
        }
        return out
    }
}