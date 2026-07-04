import Foundation

/// All pet visual states. Each maps to a sprite folder name via `PetConfig.stateSpriteMap`.
enum PetState: String, Codable, CaseIterable, Sendable {
    case idle
    case listening
    case thinking

    // Working substates — all share `working` sprite by default;
    // the subLabel distinguishes them in the Touch Bar.
    case working
    case searching
    case editing
    case running
    case reading

    case success
    case error
    case compacting
    case offline

    /// True for working.* substates.
    var isWorking: Bool {
        switch self {
        case .working, .searching, .editing, .running, .reading:
            return true
        default:
            return false
        }
    }

    /// Priority for arbitration (higher wins).
    var priority: Int {
        switch self {
        case .error:       return 100
        case .compacting:  return 90
        case .success:     return 80
        case .running, .editing, .reading, .searching, .working: return 70
        case .thinking:    return 60
        case .listening:   return 50
        case .idle:        return 10
        case .offline:     return 0
        }
    }
}