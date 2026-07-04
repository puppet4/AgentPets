#!/usr/bin/env swift

import AppKit
import Foundation

let args = CommandLine.arguments
let outputDir = URL(
    fileURLWithPath: args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath,
    isDirectory: true
)
let fileManager = FileManager.default
let iconName = "AgentPets"
let previewURL = outputDir.appendingPathComponent("\(iconName)-preview.png")
let iconsetURL = outputDir.appendingPathComponent("\(iconName).iconset", isDirectory: true)
let icnsURL = outputDir.appendingPathComponent("\(iconName).icns")

try? fileManager.removeItem(at: iconsetURL)
try? fileManager.removeItem(at: icnsURL)
try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconEntries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, dimension) in iconEntries {
    let image = try renderIcon(size: dimension)
    try pngData(from: image).write(to: iconsetURL.appendingPathComponent(fileName))
}

let previewImage = try renderIcon(size: 1024)
try pngData(from: previewImage).write(to: previewURL)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "generate-app-icon", code: Int(iconutil.terminationStatus))
}

try? fileManager.removeItem(at: iconsetURL)
print("Generated \(icnsURL.path)")
print("Preview at \(previewURL.path)")

func renderIcon(size: Int) throws -> NSImage {
    let pixelSize = NSSize(width: size, height: size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "generate-app-icon", code: 1)
    }

    rep.size = pixelSize
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "generate-app-icon", code: 2)
    }
    NSGraphicsContext.current = context

    let canvas = NSRect(origin: .zero, size: pixelSize)
    drawBackground(in: canvas)
    drawRobotAura(
        center: CGPoint(x: canvas.midX - canvas.width * 0.16, y: canvas.midY + canvas.height * 0.01),
        radius: canvas.width * 0.20,
        color: NSColor(calibratedRed: 0.91, green: 0.54, blue: 0.39, alpha: 1.0)
    )
    drawRobotAura(
        center: CGPoint(x: canvas.midX + canvas.width * 0.19, y: canvas.midY + canvas.height * 0.03),
        radius: canvas.width * 0.20,
        color: NSColor(calibratedRed: 0.41, green: 0.43, blue: 1.0, alpha: 1.0)
    )

    drawStageShadow(
        in: canvas,
        leftCenterX: canvas.midX - canvas.width * 0.17,
        rightCenterX: canvas.midX + canvas.width * 0.18
    )

    let robotUnit = canvas.width * 0.035
    drawClaudeRobot(origin: CGPoint(x: canvas.midX - canvas.width * 0.31, y: canvas.midY - canvas.height * 0.15), unit: robotUnit)
    drawCodexRobot(origin: CGPoint(x: canvas.midX + canvas.width * 0.03, y: canvas.midY - canvas.height * 0.13), unit: robotUnit)

    let image = NSImage(size: pixelSize)
    image.addRepresentation(rep)
    return image
}

func drawBackground(in rect: NSRect) {
    let radius = rect.width * 0.225
    let background = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1.0),
        NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.24, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
    ])!
    gradient.draw(in: background, angle: 270)

    NSColor.white.withAlphaComponent(0.08).setStroke()
    background.lineWidth = rect.width * 0.012
    background.stroke()

    let highlightRect = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
    let highlight = NSBezierPath(roundedRect: highlightRect, xRadius: radius * 0.72, yRadius: radius * 0.72)
    let highlightGradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.16),
        NSColor.white.withAlphaComponent(0.03),
        NSColor.clear
    ])!
    highlightGradient.draw(in: highlight, angle: 90)
}

func drawRobotAura(center: CGPoint, radius: CGFloat, color: NSColor) {
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let path = NSBezierPath(ovalIn: rect)
    let gradient = NSGradient(colors: [
        color.withAlphaComponent(0.28),
        color.withAlphaComponent(0.10),
        NSColor.clear
    ])!
    gradient.draw(in: path, relativeCenterPosition: .zero)
}

func drawStageShadow(in rect: NSRect, leftCenterX: CGFloat, rightCenterX: CGFloat) {
    let shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadowColor.setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: leftCenterX - rect.width * 0.11,
            y: rect.height * 0.18,
            width: rect.width * 0.22,
            height: rect.height * 0.055
        )
    ).fill()
    NSBezierPath(
        ovalIn: NSRect(
            x: rightCenterX - rect.width * 0.11,
            y: rect.height * 0.18,
            width: rect.width * 0.22,
            height: rect.height * 0.055
        )
    ).fill()
}

func drawClaudeRobot(origin: CGPoint, unit: CGFloat) {
    let color = NSColor(calibratedRed: 0.82, green: 0.42, blue: 0.33, alpha: 1.0)
    let eyeColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
    let legShadow = NSColor.black.withAlphaComponent(0.08)

    drawRobotBody(
        origin: origin,
        unit: unit,
        bodyColor: color,
        eyeColor: eyeColor,
        eyeStyle: .square,
        accentColor: nil
    )

    legShadow.setFill()
    NSBezierPath(rect: NSRect(x: origin.x + unit * 2.0, y: origin.y - unit * 0.15, width: unit * 0.9, height: unit * 0.3)).fill()
}

func drawCodexRobot(origin: CGPoint, unit: CGFloat) {
    let bodyColor = NSColor(calibratedRed: 0.39, green: 0.42, blue: 1.0, alpha: 1.0)
    let eyeColor = NSColor(calibratedWhite: 0.97, alpha: 1.0)
    let accentColor = NSColor(calibratedRed: 0.86, green: 0.89, blue: 1.0, alpha: 1.0)

    drawRobotBody(
        origin: origin,
        unit: unit,
        bodyColor: bodyColor,
        eyeColor: eyeColor,
        eyeStyle: .dot,
        accentColor: accentColor
    )
}

enum RobotEyeStyle {
    case square
    case dot
}

func drawRobotBody(
    origin: CGPoint,
    unit: CGFloat,
    bodyColor: NSColor,
    eyeColor: NSColor,
    eyeStyle: RobotEyeStyle,
    accentColor: NSColor?
) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = unit * 0.8
    shadow.shadowOffset = NSSize(width: 0, height: -unit * 0.3)
    shadow.set()

    bodyColor.setFill()
    fillGrid(origin: origin, unit: unit, rects: [
        (2, 8, 4, 1),
        (1, 5, 6, 3),
        (0, 5, 1, 2),
        (6, 5, 1, 2),
        (2, 3, 1, 2),
        (4, 3, 1, 2),
        (6, 3, 1, 2),
        (1, 4, 1, 1),
        (5, 4, 1, 1)
    ])

    eyeColor.setFill()
    switch eyeStyle {
    case .square:
        fillGrid(origin: origin, unit: unit, rects: [
            (2, 6, 1, 1),
            (5, 6, 1, 1)
        ])
    case .dot:
        let left = NSBezierPath(roundedRect: cellRect(origin: origin, unit: unit, x: 2.15, y: 6.05, w: 0.8, h: 0.8), xRadius: unit * 0.24, yRadius: unit * 0.24)
        left.fill()
        let right = NSBezierPath(roundedRect: cellRect(origin: origin, unit: unit, x: 5.05, y: 6.05, w: 0.8, h: 0.8), xRadius: unit * 0.24, yRadius: unit * 0.24)
        right.fill()
    }

    if let accentColor {
        accentColor.setFill()
        fillGrid(origin: origin, unit: unit, rects: [
            (3, 5, 1, 1),
            (5, 5, 1, 1),
            (4, 6, 1, 1),
            (3, 7, 1, 1),
            (5, 7, 1, 1)
        ])
    }
}

func fillGrid(origin: CGPoint, unit: CGFloat, rects: [(CGFloat, CGFloat, CGFloat, CGFloat)]) {
    for (x, y, w, h) in rects {
        NSBezierPath(rect: cellRect(origin: origin, unit: unit, x: x, y: y, w: w, h: h)).fill()
    }
}

func cellRect(origin: CGPoint, unit: CGFloat, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSRect {
    NSRect(
        x: origin.x + x * unit,
        y: origin.y + y * unit,
        width: w * unit,
        height: h * unit
    )
}

func pngData(from image: NSImage) throws -> Data {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "generate-app-icon", code: 3)
    }
    return data
}
