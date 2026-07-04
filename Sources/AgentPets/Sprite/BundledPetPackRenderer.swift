import Foundation

enum BundledPetPackRenderer {
    static let defaultPackID = AgentPackCoordinator.claudePackID

    @discardableResult
    static func writeAll(to packsDir: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)
        return try PixelRobotRole.allCases.map { role in
            try PixelRobotRenderer.writePack(role: role, to: packsDir.appendingPathComponent(role.packID))
        }
    }
}
