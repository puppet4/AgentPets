import AppKit
import XCTest
@testable import AgentPets

final class BundledPetPackRendererTests: XCTestCase {
    func testWritesClaudeAndCodexPixelPacks() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("agentpets-bundled-pets-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let written = try BundledPetPackRenderer.writeAll(to: folder)

        XCTAssertEqual(Set(written.map(\.lastPathComponent)), Set([
            AgentPackCoordinator.claudePackID,
            AgentPackCoordinator.codexPackID
        ]))
        XCTAssertEqual(BundledPetPackRenderer.defaultPackID, AgentPackCoordinator.claudePackID)

        let claudeManifest = try manifest(in: folder, packID: AgentPackCoordinator.claudePackID)
        XCTAssertEqual(claudeManifest.name, "Claude")
        XCTAssertEqual(claudeManifest.author, "AgentPets")
        XCTAssertEqual(claudeManifest.frameSize?.w, 96)
        XCTAssertEqual(claudeManifest.defaultFallback, "idle")
        XCTAssertEqual(claudeManifest.states ?? [], expectedStateNames)
        XCTAssertEqual(claudeManifest.loop ?? [:], expectedLoopMap)

        let codexManifest = try manifest(in: folder, packID: AgentPackCoordinator.codexPackID)
        XCTAssertEqual(codexManifest.name, "Codex")
        XCTAssertEqual(codexManifest.author, "AgentPets")
        XCTAssertEqual(codexManifest.states ?? [], expectedStateNames)
        XCTAssertEqual(codexManifest.loop ?? [:], expectedLoopMap)

        for packID in [AgentPackCoordinator.claudePackID, AgentPackCoordinator.codexPackID] {
            for (stateName, expectedFrameCount) in expectedFrameCounts {
                let dir = folder.appendingPathComponent(packID).appendingPathComponent(stateName)
                let frames = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension.lowercased() == "png" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                XCTAssertEqual(frames.count, expectedFrameCount, "\(packID) \(stateName) frame count")
                XCTAssertEqual(frames.first?.lastPathComponent, "00.png")
                XCTAssertEqual(frames.last?.lastPathComponent, String(format: "%02d.png", expectedFrameCount - 1))
            }
        }

        let claudeIdle = try bitmap(in: folder, packID: AgentPackCoordinator.claudePackID, frame: "idle/00.png")
        let codexIdle = try bitmap(in: folder, packID: AgentPackCoordinator.codexPackID, frame: "idle/00.png")
        let claudeWorking = try bitmap(in: folder, packID: AgentPackCoordinator.claudePackID, frame: "working/03.png")
        let codexWorking = try bitmap(in: folder, packID: AgentPackCoordinator.codexPackID, frame: "working/03.png")

        XCTAssertEqual(claudeIdle.pixelsWide, 192)
        XCTAssertEqual(claudeIdle.pixelsHigh, 192)
        XCTAssertEqual(codexIdle.pixelsWide, 192)
        XCTAssertEqual(codexIdle.pixelsHigh, 192)

        XCTAssertGreaterThan(visiblePixelCount(in: claudeIdle), 1_000)
        XCTAssertGreaterThan(visiblePixelCount(in: codexIdle), 1_000)

        let claudeColor = meanVisibleColor(in: claudeIdle)
        XCTAssertGreaterThan(claudeColor.red, claudeColor.blue)
        XCTAssertGreaterThan(claudeColor.red, claudeColor.green * 0.9)

        let codexColor = meanVisibleColor(in: codexIdle)
        XCTAssertGreaterThan(codexColor.blue, codexColor.red)
        XCTAssertGreaterThan(codexColor.blue, codexColor.green * 0.95)
        XCTAssertLessThan(codexColor.red, 0.72)
        XCTAssertTrue(dominantClaudeTileCells(in: claudeIdle).isEmpty)
        XCTAssertTrue(dominantCodexTileCells(in: codexIdle).isEmpty)
        assertCodexBlueVioletSample(sampledGridColor(in: codexIdle, gridX: 6, gridY: 13))
        assertCodexBlueVioletSample(sampledGridColor(in: codexIdle, gridX: 9, gridY: 10))
        assertCodexBlueVioletSample(sampledGridColor(in: codexIdle, gridX: 10, gridY: 7))
        XCTAssertEqual(dominantAccentCells(in: codexIdle), expectedCodexAccentCells)
        XCTAssertEqual(dominantAccentCells(in: codexWorking), expectedCodexAccentCells)

        let claudeIdleEyePixels = darkPixelCount(
            in: claudeIdle,
            gridXRange: 7...15,
            gridYRange: 15...17
        )
        let claudeWorkingEyePixels = darkPixelCount(
            in: claudeWorking,
            gridXRange: 7...15,
            gridYRange: 15...17
        )
        XCTAssertGreaterThan(claudeIdleEyePixels, 110)
        XCTAssertGreaterThan(claudeWorkingEyePixels, 45)
        XCTAssertLessThan(claudeWorkingEyePixels, 80)
        XCTAssertLessThan(claudeWorkingEyePixels, claudeIdleEyePixels)
    }

    func testClaudeIdleBlueprintMatchesApprovedReferenceRobot() {
        let blueprint = PixelRobotRenderer.idleBlueprint(for: .claude)
        let tileRect = PixelRobotRole.claude.tileRect
        let head = blueprint.bodyRects[0]
        let lowerBody = blueprint.bodyRects[2]

        XCTAssertEqual(blueprint, .init(
            bodyRects: [
                .init(x: 7, y: 15, width: 10, height: 3),
                .init(x: 5, y: 12, width: 14, height: 3),
                .init(x: 7, y: 9, width: 10, height: 3),
                .init(x: 7, y: 6, width: 1, height: 3),
                .init(x: 10, y: 6, width: 1, height: 3),
                .init(x: 14, y: 6, width: 1, height: 3),
                .init(x: 16, y: 6, width: 1, height: 3)
            ],
            eyeRects: [
                .init(x: 8, y: 16, width: 1, height: 1),
                .init(x: 14, y: 16, width: 1, height: 1)
            ],
            accentRects: []
        ))
        XCTAssertEqual(head.x, lowerBody.x)
        XCTAssertEqual(head.width, lowerBody.width)
        XCTAssertEqual(tileRect, NSRect(x: 1, y: 3, width: 22, height: 18))
        XCTAssertTrue(blueprint.accentRects.isEmpty)
    }

    func testClaudeWorkingEyesUseCrossedGlyph() {
        XCTAssertEqual(PixelRobotRenderer.claudeEyeStyle(for: "idle"), .square)
        XCTAssertEqual(PixelRobotRenderer.claudeEyeStyle(for: "working"), .crossed)
    }

    func testCodexIdleBlueprintMatchesMinimalClaudeFamilyRobot() {
        let codex = PixelRobotRenderer.idleBlueprint(for: .codex)
        let claude = PixelRobotRenderer.idleBlueprint(for: .claude)

        XCTAssertEqual(codex, .init(
            bodyRects: claude.bodyRects,
            eyeRects: claude.eyeRects,
            accentRects: [
                .init(x: 10, y: 17, width: 1, height: 1),
                .init(x: 12, y: 17, width: 1, height: 1),
                .init(x: 11, y: 16, width: 1, height: 1),
                .init(x: 10, y: 15, width: 1, height: 1),
                .init(x: 12, y: 15, width: 1, height: 1)
            ]
        ))
        XCTAssertEqual(PixelRobotRole.codex.tileRect, NSRect(x: 1, y: 3, width: 22, height: 18))
    }

    func testCodexPaletteMatchesBlueVioletReference() throws {
        let body = try XCTUnwrap(PixelRobotRole.codex.bodyColor.usingColorSpace(.deviceRGB))
        XCTAssertEqual(body.redComponent, expectedCodexBodyColor.redComponent, accuracy: 0.001)
        XCTAssertEqual(body.greenComponent, expectedCodexBodyColor.greenComponent, accuracy: 0.001)
        XCTAssertEqual(body.blueComponent, expectedCodexBodyColor.blueComponent, accuracy: 0.001)

        let accent = try XCTUnwrap(PixelRobotRole.codex.accentColor.usingColorSpace(.deviceRGB))
        XCTAssertEqual(accent.redComponent, expectedCodexAccentColor.redComponent, accuracy: 0.001)
        XCTAssertEqual(accent.greenComponent, expectedCodexAccentColor.greenComponent, accuracy: 0.001)
        XCTAssertEqual(accent.blueComponent, expectedCodexAccentColor.blueComponent, accuracy: 0.001)
    }

    private let expectedStateNames = [
        "idle",
        "listening",
        "thinking",
        "working",
        "success",
        "error",
        "offline"
    ]

    private let expectedLoopMap = [
        "idle": true,
        "listening": true,
        "thinking": true,
        "working": true,
        "success": false,
        "error": false,
        "offline": true
    ]

    private let expectedFrameCounts: [(String, Int)] = [
        ("idle", 6),
        ("listening", 4),
        ("thinking", 4),
        ("working", 8),
        ("success", 6),
        ("error", 4),
        ("offline", 4)
    ]

    private let expectedCodexAccentCells: Set<String> = [
        "10,15",
        "12,15",
        "11,16",
        "10,17",
        "12,17"
    ]

    private let expectedCodexBodyColor = NSColor(red: 0.54, green: 0.53, blue: 0.97, alpha: 1.0)
    private let expectedCodexAccentColor = NSColor(red: 0.90, green: 0.91, blue: 0.99, alpha: 1.0)

    private func manifest(in folder: URL, packID: String) throws -> PackManifest {
        let data = try Data(contentsOf: folder.appendingPathComponent(packID).appendingPathComponent("pack.json"))
        return try JSONDecoder().decode(PackManifest.self, from: data)
    }

    private func bitmap(in folder: URL, packID: String, frame: String) throws -> NSBitmapImageRep {
        let url = folder.appendingPathComponent(packID).appendingPathComponent(frame)
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        return try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
    }

    private func visiblePixelCount(in rep: NSBitmapImageRep) -> Int {
        var count = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                    count += 1
                }
            }
        }
        return count
    }

    private func meanVisibleColor(in rep: NSBitmapImageRep) -> (red: Double, green: Double, blue: Double) {
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0.0

        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.05 else { continue }
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                count += 1
            }
        }

        guard count > 0 else { return (0, 0, 0) }
        return (red / count, green / count, blue / count)
    }

    private func dominantAccentCells(in rep: NSBitmapImageRep) -> Set<String> {
        let target = expectedCodexAccentColor.usingColorSpace(.deviceRGB) ?? expectedCodexAccentColor

        return dominantCells(
            in: rep,
            isMatch: { color in
                let redDelta = abs(color.redComponent - target.redComponent)
                let greenDelta = abs(color.greenComponent - target.greenComponent)
                let blueDelta = abs(color.blueComponent - target.blueComponent)

                return color.alphaComponent > 0.9 &&
                    color.redComponent > 0.86 &&
                    color.greenComponent > 0.87 &&
                    color.blueComponent > 0.95 &&
                    color.blueComponent > color.greenComponent &&
                    color.greenComponent > color.redComponent &&
                    redDelta < 0.04 &&
                    greenDelta < 0.04 &&
                    blueDelta < 0.04
            }
        )
    }

    private func dominantClaudeTileCells(in rep: NSBitmapImageRep) -> Set<String> {
        dominantCells(
            in: rep,
            matching: NSColor(red: 0.96, green: 0.93, blue: 0.90, alpha: 0.98),
            tolerance: 0.04,
            minAlpha: 0.85
        )
    }

    private func dominantCodexTileCells(in rep: NSBitmapImageRep) -> Set<String> {
        dominantCells(
            in: rep,
            matching: NSColor(red: 0.70, green: 0.78, blue: 0.88, alpha: 0.98),
            tolerance: 0.04,
            minAlpha: 0.85
        )
    }

    private func dominantCells(
        in rep: NSBitmapImageRep,
        matching target: NSColor,
        tolerance: Double,
        minAlpha: Double
    ) -> Set<String> {
        let resolved = target.usingColorSpace(.deviceRGB) ?? target
        return dominantCells(
            in: rep,
            isMatch: { color in
                let redDelta = abs(color.redComponent - resolved.redComponent)
                let greenDelta = abs(color.greenComponent - resolved.greenComponent)
                let blueDelta = abs(color.blueComponent - resolved.blueComponent)

                return color.alphaComponent >= minAlpha &&
                    redDelta <= tolerance &&
                    greenDelta <= tolerance &&
                    blueDelta <= tolerance
            }
        )
    }

    private func dominantCells(
        in rep: NSBitmapImageRep,
        isMatch: (NSColor) -> Bool
    ) -> Set<String> {
        let designGrid = 24
        let cellSize = rep.pixelsWide / designGrid
        var matches: Set<String> = []

        for gridX in 0..<designGrid {
            for gridY in 0..<designGrid {
                var hitCount = 0

                for pixelX in (gridX * cellSize)..<((gridX + 1) * cellSize) {
                    for pixelY in (gridY * cellSize)..<((gridY + 1) * cellSize) {
                        guard let color = rep.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.deviceRGB) else { continue }
                        if isMatch(color) {
                            hitCount += 1
                        }
                    }
                }

                if hitCount >= cellSize * cellSize / 3 {
                    matches.insert("\(gridX),\(designGrid - 1 - gridY)")
                }
            }
        }

        return matches
    }

    private func darkPixelCount(
        in rep: NSBitmapImageRep,
        gridXRange: ClosedRange<Int>,
        gridYRange: ClosedRange<Int>
    ) -> Int {
        let designGrid = 24
        let cellSize = rep.pixelsWide / designGrid
        var count = 0

        for pixelX in 0..<rep.pixelsWide {
            let gridX = pixelX / cellSize
            guard gridXRange.contains(gridX) else { continue }

            for pixelY in 0..<rep.pixelsHigh {
                let designY = designGrid - 1 - (pixelY / cellSize)
                guard gridYRange.contains(designY),
                      let color = rep.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.deviceRGB) else { continue }

                let maxChannel = max(color.redComponent, max(color.greenComponent, color.blueComponent))
                if color.alphaComponent > 0.35 && maxChannel < 0.22 {
                    count += 1
                }
            }
        }

        return count
    }

    private func sampledGridColor(
        in rep: NSBitmapImageRep,
        gridX: Int,
        gridY: Int
    ) -> NSColor {
        let designGrid = 24
        let cellSize = rep.pixelsWide / designGrid
        let pixelX = gridX * cellSize + cellSize / 2
        let pixelY = (designGrid - 1 - gridY) * cellSize + cellSize / 2
        return (rep.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.deviceRGB)) ?? .clear
    }

    private func assertCodexBlueVioletSample(
        _ color: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(color.blueComponent, 0.94, file: file, line: line)
        XCTAssertGreaterThan(color.blueComponent - color.greenComponent, 0.30, file: file, line: line)
        XCTAssertLessThan(abs(color.redComponent - color.greenComponent), 0.04, file: file, line: line)
        XCTAssertGreaterThan(color.alphaComponent, 0.95, file: file, line: line)
    }
}
