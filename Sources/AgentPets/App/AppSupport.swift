import Foundation

enum AppSupport {
    static let directoryName = "AgentPets"
    static let bundleIdentifier = "com.agentpets.app"

    static var supportDir: URL {
        supportDir(homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    }

    static func supportDir(homeDirectory: URL) -> URL {
        applicationSupportDir(named: directoryName, homeDirectory: homeDirectory)
    }

    @discardableResult
    static func prepareSupportDirectory(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let supportDir = supportDir(homeDirectory: homeDirectory)
        let supportParent = supportDir.deletingLastPathComponent()

        try fileManager.createDirectory(at: supportParent, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
        return supportDir
    }

    private static func applicationSupportDir(named directoryName: String, homeDirectory: URL) -> URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }
}
