import SwiftUI
import AppKit

/// Drives sprite-frame playback for the active state. Uses `TimelineView(.animation)`
/// so it stays in lockstep with the system display link and respects SwiftUI's
/// rate-limiting automatically.
struct SpritePlayer: View {
    let state: PetState
    let pack: Pack
    let fps: Double
    let spriteMapName: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / max(fps, 1.0))) { ctx in
            let images = pack.images(forState: state, mapName: spriteMapName)
            let count = images.count
            let loop = pack.loopEnabled(for: spriteMapName)
            let i = frameIndex(now: ctx.date, count: count, loop: loop, state: state)
            Group {
                if images.indices.contains(i) {
                    Image(nsImage: images[i])
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    EmptyView()
                }
            }
        }
        .id("\(pack.name)::\(spriteMapName)")   // reset timeline when pack or sprite changes
    }

    /// Stable per-(pack, state) playback so animation continues smoothly
    /// even if the view re-renders.
    private func frameIndex(now: Date, count: Int, loop: Bool, state: PetState) -> Int {
        guard count > 0 else { return 0 }
        let interval = 1.0 / max(fps, 1.0)
        let elapsed = now.timeIntervalSinceReferenceDate
        let absolute = Int(elapsed / interval)
        if loop {
            return absolute % count
        } else {
            return min(absolute, count - 1)
        }
    }
}