import AppKit

/// Generates simple geometric placeholder sprites when the user hasn't provided any yet.
/// Makes the app usable out of the box while clearly signaling "this is a placeholder".
enum PlaceholderRenderer {
    static func renderFrames(state: String, palette: [NSColor], size: CGSize, count: Int) -> [NSImage] {
        var out: [NSImage] = []
        for i in 0..<count {
            let img = NSImage(size: size)
            img.lockFocus()
            defer { img.unlockFocus() }
            renderCircle(state: state, palette: palette, size: size, frameIndex: i, count: count)
            out.append(img)
        }
        return out
    }

    private static func renderCircle(state: String, palette: [NSColor], size: CGSize, frameIndex i: Int, count: Int) {
        let primary = palette.first ?? .systemGray
        let progress = count > 1 ? Double(i) / Double(count - 1) : 0.5
        let inset: CGFloat = 2
        let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)

        // Soft glow
        primary.withAlphaComponent(0.25).setFill()
        let glow = NSBezierPath(ovalIn: rect.insetBy(dx: -2, dy: -2))
        glow.fill()

        // Main blob
        primary.setFill()
        NSBezierPath(ovalIn: rect).fill()

        // Eyes — animate slightly
        let eyeColor = NSColor.white
        eyeColor.setFill()
        let eyeY = size.height * 0.62
        let eyeOffset = sin(progress * .pi * 2) * 1.0
        let eyeSize: CGFloat = 2.5
        let leftEye = NSRect(x: size.width * 0.30 + eyeOffset, y: eyeY, width: eyeSize, height: eyeSize)
        let rightEye = NSRect(x: size.width * 0.62 + eyeOffset, y: eyeY, width: eyeSize, height: eyeSize)
        NSBezierPath(ovalIn: leftEye).fill()
        NSBezierPath(ovalIn: rightEye).fill()

        // State-specific ornament
        switch state {
        case "thinking":
            NSColor.white.setStroke()
            let q = NSBezierPath()
            q.move(to: NSPoint(x: size.width * 0.78, y: size.height * 0.30))
            q.curve(to: NSPoint(x: size.width * 0.92, y: size.height * 0.50),
                    controlPoint1: NSPoint(x: size.width * 0.92, y: size.height * 0.30),
                    controlPoint2: NSPoint(x: size.width * 0.88, y: size.height * 0.42))
            q.lineWidth = 1.5
            q.stroke()
        case "error":
            NSColor.white.setStroke()
            let x = NSBezierPath()
            x.move(to: NSPoint(x: size.width * 0.40, y: size.height * 0.32))
            x.line(to: NSPoint(x: size.width * 0.60, y: size.height * 0.52))
            x.move(to: NSPoint(x: size.width * 0.60, y: size.height * 0.32))
            x.line(to: NSPoint(x: size.width * 0.40, y: size.height * 0.52))
            x.lineWidth = 2
            x.stroke()
        case "success":
            NSColor.white.setStroke()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: size.width * 0.38, y: size.height * 0.45))
            check.line(to: NSPoint(x: size.width * 0.47, y: size.height * 0.36))
            check.line(to: NSPoint(x: size.width * 0.62, y: size.height * 0.55))
            check.lineWidth = 2
            check.lineCapStyle = .round
            check.stroke()
        case "working":
            // small "feet" indicating motion
            NSColor.white.withAlphaComponent(0.7).setFill()
            let bobY = size.height * 0.18 + sin(progress * .pi * 2) * 1.0
            let foot = NSBezierPath(ovalIn: NSRect(x: size.width * 0.35, y: bobY, width: 2, height: 2))
            foot.fill()
            let foot2 = NSBezierPath(ovalIn: NSRect(x: size.width * 0.60, y: bobY, width: 2, height: 2))
            foot2.fill()
        default:
            break
        }
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}