import Foundation

/// UserDefaults-backed persistence. We only persist enough to make restarts
/// look reasonable when Claude is mid-task.
@MainActor
final class StateStore {
    private let d = UserDefaults.standard
    private let lastStateKey = "pet.lastState"
    private let lastEventAtKey = "pet.lastEventAt"
    private let activePackKey = "pet.activePack"

    func restore(model: PetModel, config: PetConfig) {
        if let raw = d.string(forKey: lastStateKey),
           let parsed = PetState(rawValue: raw),
           let lastAt = d.object(forKey: lastEventAtKey) as? Date,
           Date().timeIntervalSince(lastAt) < 60 {
            model.state = parsed
            model.lastEventAt = lastAt
        } else {
            model.state = .idle
        }
        model.apply(config)
    }

    func persist(model: PetModel) {
        d.set(model.state.rawValue, forKey: lastStateKey)
        d.set(model.lastEventAt, forKey: lastEventAtKey)
    }

    func persistActivePack(_ name: String) {
        d.set(name, forKey: activePackKey)
    }

    func loadActivePack() -> String? {
        d.string(forKey: activePackKey)
    }
}