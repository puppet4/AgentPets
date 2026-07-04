import AppKit
import Foundation

struct BundledPackStateSpec: Equatable {
    let name: String
    let frameCount: Int
    let loops: Bool
}

enum PixelRobotRole: CaseIterable {
    case claude
    case codex

    var packID: String {
        switch self {
        case .claude:
            return AgentPackCoordinator.claudePackID
        case .codex:
            return AgentPackCoordinator.codexPackID
        }
    }

    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        }
    }

    var tileColor: NSColor {
        switch self {
        case .claude:
            return NSColor(red: 0.96, green: 0.93, blue: 0.90, alpha: 0.98)
        case .codex:
            return NSColor(red: 0.70, green: 0.78, blue: 0.88, alpha: 0.98)
        }
    }

    var bodyColor: NSColor {
        switch self {
        case .claude:
            return NSColor(red: 0.84, green: 0.42, blue: 0.29, alpha: 1.0)
        case .codex:
            return NSColor(red: 0.54, green: 0.53, blue: 0.97, alpha: 1.0)
        }
    }

    var accentColor: NSColor {
        switch self {
        case .claude:
            return NSColor(red: 0.93, green: 0.67, blue: 0.42, alpha: 1.0)
        case .codex:
            return NSColor(red: 0.90, green: 0.91, blue: 0.99, alpha: 1.0)
        }
    }

    var shadowColor: NSColor {
        switch self {
        case .claude:
            return NSColor.black.withAlphaComponent(0.14)
        case .codex:
            return NSColor.black.withAlphaComponent(0.18)
        }
    }

    var tileRect: NSRect {
        switch self {
        case .claude, .codex:
            return NSRect(x: 1, y: 3, width: 22, height: 18)
        }
    }
}

enum PixelRobotRenderer {
    enum ClaudeEyeStyle: Equatable {
        case square
        case crossed
    }

    struct PixelRect: Equatable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    struct RobotBlueprint: Equatable {
        let bodyRects: [PixelRect]
        let eyeRects: [PixelRect]
        let accentRects: [PixelRect]
    }

    private static let gridSize: CGFloat = 24
    private static let pixelSize: CGFloat = 192
    private static let pointSize: CGFloat = 96
    private static let pixelScale = pixelSize / gridSize

    static let bundledStateSpec: [BundledPackStateSpec] = [
        BundledPackStateSpec(name: "idle", frameCount: 6, loops: true),
        BundledPackStateSpec(name: "listening", frameCount: 4, loops: true),
        BundledPackStateSpec(name: "thinking", frameCount: 4, loops: true),
        BundledPackStateSpec(name: "working", frameCount: 8, loops: true),
        BundledPackStateSpec(name: "success", frameCount: 6, loops: false),
        BundledPackStateSpec(name: "error", frameCount: 4, loops: false),
        BundledPackStateSpec(name: "offline", frameCount: 4, loops: true)
    ]

    private static let claudeIdleRobot = RobotBlueprint(
        bodyRects: [
            PixelRect(x: 7, y: 15, width: 10, height: 3),
            PixelRect(x: 5, y: 12, width: 14, height: 3),
            PixelRect(x: 7, y: 9, width: 10, height: 3),
            PixelRect(x: 7, y: 6, width: 1, height: 3),
            PixelRect(x: 10, y: 6, width: 1, height: 3),
            PixelRect(x: 14, y: 6, width: 1, height: 3),
            PixelRect(x: 16, y: 6, width: 1, height: 3)
        ],
        eyeRects: [
            PixelRect(x: 8, y: 16, width: 1, height: 1),
            PixelRect(x: 14, y: 16, width: 1, height: 1)
        ],
        accentRects: []
    )

    private static let codexIdleRobot = RobotBlueprint(
        bodyRects: claudeIdleRobot.bodyRects,
        eyeRects: claudeIdleRobot.eyeRects,
        accentRects: [
            PixelRect(x: 10, y: 17, width: 1, height: 1),
            PixelRect(x: 12, y: 17, width: 1, height: 1),
            PixelRect(x: 11, y: 16, width: 1, height: 1),
            PixelRect(x: 10, y: 15, width: 1, height: 1),
            PixelRect(x: 12, y: 15, width: 1, height: 1)
        ]
    )

    static func idleBlueprint(for role: PixelRobotRole) -> RobotBlueprint {
        switch role {
        case .claude:
            return claudeIdleRobot
        case .codex:
            return codexIdleRobot
        }
    }

    static func claudeEyeStyle(for state: String) -> ClaudeEyeStyle {
        switch state {
        case "working":
            return .crossed
        default:
            return .square
        }
    }

    @discardableResult
    static func writePack(role: PixelRobotRole, to folder: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let manifest = PackManifest(
            name: role.displayName,
            author: "AgentPets",
            version: 1,
            frameSize: PackManifest.FrameSize(w: pointSize, h: pointSize),
            states: bundledStateSpec.map(\.name),
            defaultFallback: "idle",
            loop: Dictionary(uniqueKeysWithValues: bundledStateSpec.map { ($0.name, $0.loops) })
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: folder.appendingPathComponent("pack.json"))

        for spec in bundledStateSpec {
            let state = spec.name
            let count = spec.frameCount
            let dir = folder.appendingPathComponent(state)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            if let existing = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for old in existing where old.pathExtension.lowercased() == "png" {
                    try? fm.removeItem(at: old)
                }
            }

            for index in 0..<count {
                let image = renderFrame(role: role, state: state, index: index, count: count)
                guard let data = pngData(from: image) else {
                    throw FrameEncodingError(role: role, state: state, index: index)
                }
                try data.write(to: dir.appendingPathComponent(String(format: "%02d.png", index)))
            }
        }

        return folder
    }

    private static func renderFrame(role: PixelRobotRole, state: String, index: Int, count: Int) -> NSImage {
        let progress = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.5
        let cycle = progress * .pi * 2
        let pose = pose(for: role, state: state, cycle: cycle, progress: progress)

        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let cg = CGContext(
            data: nil,
            width: Int(pixelSize),
            height: Int(pixelSize),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: bitmapInfo
        ) else { return NSImage() }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        cg.scaleBy(x: pixelScale, y: pixelScale)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

        drawShadow(role: role, offsetX: pose.offsetX)
        drawRobot(role: role, pose: pose)
        drawStateAccent(role: role, state: state, progress: progress, pose: pose)

        guard let cgImage = cg.makeImage() else { return NSImage() }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        return image
    }

    private static func pose(for role: PixelRobotRole, state: String, cycle: CGFloat, progress: CGFloat) -> Pose {
        var pose = Pose()
        pose.eyeBlink = false

        switch state {
        case "idle":
            pose.offsetY = sin(cycle) * 0.35
        case "listening":
            pose.offsetY = 0.35
            pose.tilePulse = 0.06
            pose.eyeWidth = role == .codex ? 0.9 : 1.0
        case "thinking":
            pose.offsetY = 0.2
            pose.lean = role == .claude ? -0.5 : 0.2
            pose.eyeOffsetX = role == .claude ? sin(cycle) * 0.35 : 0
        case "working":
            pose.offsetX = role == .claude ? sin(cycle * 2) * 0.25 : sin(cycle * 2) * 0.22
            pose.offsetY = abs(sin(cycle * 2)) * 0.42
        case "success":
            pose.offsetY = sin(progress * .pi) * 1.6
            pose.tilePulse = 0.10
        case "error":
            pose.offsetX = sin(cycle * 4) * 0.5
            pose.eyeBlink = true
        case "offline":
            pose.offsetY = -0.8
            pose.alpha = 0.55
            pose.eyeBlink = true
        default:
            break
        }

        if role == .claude {
            pose.tileOffsetY += 0.1
            pose.claudeEyeStyle = claudeEyeStyle(for: state)
        } else {
            pose.tileOffsetX -= 0.1
        }

        return pose
    }

    private static func drawShadow(role: PixelRobotRole, offsetX: CGFloat) {
        role.shadowColor.setFill()
        let rect = NSRect(
            x: 4.1 - offsetX * 0.12,
            y: 1.9,
            width: 15.8,
            height: 1.7
        )
        NSBezierPath(ovalIn: rect).fill()
    }

    private static func drawRobot(role: PixelRobotRole, pose: Pose) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let transform = NSAffineTransform()
        transform.translateX(by: pose.offsetX, yBy: pose.offsetY)
        transform.translateX(by: 12, yBy: 11.5)
        transform.rotate(byDegrees: pose.lean * 4)
        transform.translateX(by: -12, yBy: -11.5)
        transform.concat()

        switch role {
        case .claude:
            drawClaude(pose: pose)
        case .codex:
            drawCodex(pose: pose)
        }
    }

    private static func drawClaude(pose: Pose) {
        let alpha = pose.alpha
        let body = PixelRobotRole.claude.bodyColor.withAlphaComponent(alpha)
        let eye = NSColor.black.withAlphaComponent(alpha)
        let blueprint = idleBlueprint(for: .claude)

        fill(blueprint.bodyRects, color: body)

        let blinkHeight: CGFloat = pose.eyeBlink ? 0.35 : 1.0
        let eyeLift: CGFloat = pose.eyeBlink ? 0.25 : 0
        let leftEyeOffset = pose.eyeOffsetX
        let rightEyeOffset = -pose.eyeOffsetX
        let anchors = blueprint.eyeRects
        if anchors.count == 2 {
            let left = anchors[0]
            let right = anchors[1]
            if pose.claudeEyeStyle == .crossed, pose.eyeBlink == false {
                drawClaudeChevronEye(
                    x: CGFloat(left.x) + leftEyeOffset,
                    y: CGFloat(left.y),
                    direction: .right,
                    color: eye
                )
                drawClaudeChevronEye(
                    x: CGFloat(right.x) + rightEyeOffset,
                    y: CGFloat(right.y),
                    direction: .left,
                    color: eye
                )
            } else {
                fill(
                    x: CGFloat(left.x) + leftEyeOffset,
                    y: CGFloat(left.y) + eyeLift,
                    w: CGFloat(left.width) * pose.eyeWidth,
                    h: blinkHeight,
                    color: eye
                )
                fill(
                    x: CGFloat(right.x) + rightEyeOffset,
                    y: CGFloat(right.y) + eyeLift,
                    w: CGFloat(right.width) * pose.eyeWidth,
                    h: blinkHeight,
                    color: eye
                )
            }
        }
    }

    private static func drawCodex(pose: Pose) {
        let alpha = pose.alpha
        let body = PixelRobotRole.codex.bodyColor.withAlphaComponent(alpha)
        let eye = NSColor(red: 0.11, green: 0.14, blue: 0.18, alpha: alpha)
        let accent = PixelRobotRole.codex.accentColor.withAlphaComponent(alpha)
        let blueprint = idleBlueprint(for: .codex)

        fill(blueprint.bodyRects, color: body)
        fill(blueprint.eyeRects, color: eye)
        fill(blueprint.accentRects, color: accent)
    }

    private static func drawStateAccent(role: PixelRobotRole, state: String, progress: CGFloat, pose: Pose) {
        switch state {
        case "thinking":
            if role == .claude {
                fill(x: 16.7, y: 18.3 + sin(progress * .pi * 2) * 0.2, w: 1, h: 1, color: role.accentColor.withAlphaComponent(0.85))
                fill(x: 18.0, y: 19.3 + sin(progress * .pi * 2) * 0.2, w: 1, h: 1, color: role.accentColor.withAlphaComponent(0.65))
            } else {
                let drift = sin(progress * .pi * 2) * 0.15
                fill(x: 17.0, y: 18.1 + drift, w: 0.8, h: 0.8, color: role.accentColor.withAlphaComponent(0.80))
                fill(x: 18.1, y: 18.8 + drift, w: 0.8, h: 0.8, color: role.accentColor.withAlphaComponent(0.62))
                fill(x: 19.1, y: 19.5 + drift, w: 0.7, h: 0.7, color: role.accentColor.withAlphaComponent(0.48))
            }
        case "success":
            let sparkleY = 18.0 + sin(progress * .pi) * 0.8
            fill(x: role == .codex ? 18.0 : 17.0, y: sparkleY, w: 1, h: 1, color: role.accentColor.withAlphaComponent(0.9))
            fill(x: role == .codex ? 18.5 : 17.5, y: sparkleY + 1.0, w: 1, h: 1, color: NSColor.white.withAlphaComponent(0.9))
        case "error":
            let color = NSColor(red: 0.94, green: 0.34, blue: 0.28, alpha: 0.95 * pose.alpha)
            fill(x: 17.0, y: 18.0, w: 1, h: 2, color: color)
            fill(x: 17.0, y: 17.0, w: 1, h: 0.7, color: color)
        case "offline":
            let color = NSColor.black.withAlphaComponent(0.25)
            fill(x: 17.0, y: 18.0, w: 1.6, h: 0.4, color: color)
            fill(x: 18.1, y: 19.0, w: 1.1, h: 0.4, color: color)
        default:
            break
        }
    }

    private static func fill(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: NSColor) {
        color.setFill()
        NSBezierPath(rect: NSRect(x: x, y: y, width: w, height: h)).fill()
    }

    private static func fill(_ rect: PixelRect, color: NSColor) {
        fill(
            x: CGFloat(rect.x),
            y: CGFloat(rect.y),
            w: CGFloat(rect.width),
            h: CGFloat(rect.height),
            color: color
        )
    }

    private static func fill(_ rects: [PixelRect], color: NSColor) {
        for rect in rects {
            fill(rect, color: color)
        }
    }

    private enum ClaudeChevronDirection {
        case left
        case right
    }

    private static func drawClaudeChevronEye(
        x: CGFloat,
        y: CGFloat,
        direction: ClaudeChevronDirection,
        color: NSColor
    ) {
        switch direction {
        case .right:
            fill(x: x, y: y + 0.75, w: 0.55, h: 0.4, color: color)
            fill(x: x + 0.55, y: y + 0.35, w: 0.55, h: 0.4, color: color)
            fill(x: x, y: y - 0.05, w: 0.55, h: 0.4, color: color)
        case .left:
            fill(x: x + 0.55, y: y + 0.75, w: 0.55, h: 0.4, color: color)
            fill(x: x, y: y + 0.35, w: 0.55, h: 0.4, color: color)
            fill(x: x + 0.55, y: y - 0.05, w: 0.55, h: 0.4, color: color)
        }
    }

    private static func pngData(from image: NSImage) -> Data? {
        if let rep = image.representations.first as? NSBitmapImageRep {
            return rep.representation(using: .png, properties: [:])
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private struct Pose {
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        var tileOffsetX: CGFloat = 0
        var tileOffsetY: CGFloat = 0
        var tilePulse: CGFloat = 0
        var lean: CGFloat = 0
        var alpha: CGFloat = 1
        var eyeWidth: CGFloat = 1
        var eyeBlink = false
        var eyeOffsetX: CGFloat = 0
        var claudeEyeStyle: ClaudeEyeStyle = .square
    }

    private struct FrameEncodingError: LocalizedError {
        let role: PixelRobotRole
        let state: String
        let index: Int

        var errorDescription: String? {
            "Failed to encode PNG frame for \(role.packID) state=\(state) index=\(index)"
        }
    }
}
