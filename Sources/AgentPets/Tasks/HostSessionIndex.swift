import Foundation

final class HostSessionIndex {
    typealias ITermEnumerator = () throws -> String

    private let iTermEnumerator: ITermEnumerator

    init(iTermEnumerator: @escaping ITermEnumerator = HostSessionIndex.runITermEnumerator) {
        self.iTermEnumerator = iTermEnumerator
    }

    func sessions() -> [HostSessionInfo] {
        var all: [HostSessionInfo] = []
        if let iTerm = try? parseITermOutput(iTermEnumerator()) {
            all.append(contentsOf: iTerm)
        }
        return all
    }

    private func parseITermOutput(_ output: String) throws -> [HostSessionInfo] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let parts = String(line).split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
                guard parts.count == 4,
                      let windowID = Int(parts[0]),
                      let tabIndex = Int(parts[1]) else {
                    return nil
                }

                let tty = String(parts[2]).replacingOccurrences(of: "/dev/", with: "")
                let title = String(parts[3])
                return HostSessionInfo(
                    host: .iTerm2,
                    tty: tty,
                    title: title,
                    location: .iTerm2(windowID: windowID, tabIndex: tabIndex, tty: tty),
                    activationCapability: .exact
                )
            }
    }

    private static func runITermEnumerator() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "tell application \"iTerm2\"",
            "-e", "set outputLines to {}",
            "-e", "repeat with w in windows",
            "-e", "set windowID to id of w",
            "-e", "set tabCount to count of tabs of w",
            "-e", "repeat with tabIndex from 1 to tabCount",
            "-e", "set t to tab tabIndex of w",
            "-e", "repeat with s in sessions of t",
            "-e", "set end of outputLines to ((windowID as string) & \"|\" & (tabIndex as string) & \"|\" & (tty of s as string) & \"|\" & (name of s as string))",
            "-e", "end repeat",
            "-e", "end repeat",
            "-e", "end repeat",
            "-e", "set AppleScript's text item delimiters to linefeed",
            "-e", "return outputLines as text",
            "-e", "end tell"
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "osascript failed"
            throw NSError(domain: "HostSessionIndex", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
