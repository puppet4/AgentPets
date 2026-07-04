import XCTest

final class PetNotifyScriptTests: XCTestCase {
    func testPetNotifyAddsTaskMetadataWithoutDroppingPayload() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = repoRoot
            .appendingPathComponent("Sources/AgentPets/Resources/pet-notify.sh")
        let inboxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpets-pet-notify-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = scriptURL
        process.environment = [
            "AGENT_PETS_INBOX": inboxURL.path,
            "TERM_PROGRAM": "iTerm.app",
            "TERM_SESSION_ID": "w0t0p0:test",
            "ITERM_SESSION_ID": "w0t0p0:test",
            "PWD": "/Users/kangjialv/Desktop"
        ]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output

        try process.run()
        input.fileHandleForWriting.write(Data(#"{"hook_event_name":"PreToolUse","tool_name":"Read"}"#.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)

        let files = try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)

        let data = try Data(contentsOf: files[0])
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["hook_event_name"] as? String, "PreToolUse")
        let meta = try XCTUnwrap(object["task_meta"] as? [String: Any])
        XCTAssertEqual(meta["term_program"] as? String, "iTerm.app")
        XCTAssertEqual(meta["term_session_id"] as? String, "w0t0p0:test")
        XCTAssertEqual(meta["cwd"] as? String, repoRoot.path)
    }
}
