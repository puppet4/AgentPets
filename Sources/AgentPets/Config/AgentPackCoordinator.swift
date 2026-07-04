import Foundation

enum AgentPackCoordinator {
    static let claudePackID = "claude-pixel"
    static let codexPackID = "codex-pixel"
    static let productPackIDs: Set<String> = [claudePackID, codexPackID]

    static func packID(for agent: TerminalAgent) -> String {
        switch agent {
        case .claude:
            claudePackID
        case .codex:
            codexPackID
        }
    }

    static func reconcileFollowMode(currentAgent: TerminalAgent?, config: PetConfig) -> PetConfig {
        let normalized = normalizeProductPack(config, preferredAgent: config.followActiveAgent ? currentAgent : nil)
        guard normalized.followActiveAgent else { return normalized }

        var updated = normalized
        if let currentAgent {
            updated.activePack = packID(for: currentAgent)
            return updated
        }

        guard !isProductPack(normalized.activePack) else { return normalized }
        updated.activePack = claudePackID
        return updated
    }

    static func applyDetectedTasks(_ tasks: [AgentTaskSnapshot], to config: PetConfig) -> PetConfig {
        reconcileFollowMode(
            currentAgent: AgentTaskSnapshot.aggregate(from: tasks)?.agent,
            config: config
        )
    }

    static func applyDetectedAgent(_ agent: TerminalAgent?, to config: PetConfig) -> PetConfig {
        reconcileFollowMode(currentAgent: agent, config: config)
    }

    static func applyManualSelection(packID: String, to config: PetConfig) -> PetConfig {
        var updated = config
        updated.activePack = isProductPack(packID) ? packID : claudePackID
        updated.followActiveAgent = false
        return updated
    }

    static func applyProductSelection(packID: String, to config: PetConfig) -> PetConfig {
        var updated = config
        updated.activePack = isProductPack(packID) ? packID : claudePackID
        return updated
    }

    static func setFollowActiveAgent(
        _ isEnabled: Bool,
        currentAgent: TerminalAgent?,
        config: PetConfig
    ) -> PetConfig {
        var updated = config
        updated.followActiveAgent = isEnabled

        guard isEnabled else { return updated }
        return reconcileFollowMode(currentAgent: currentAgent, config: updated)
    }

    static func normalizeProductPack(_ config: PetConfig, preferredAgent: TerminalAgent?) -> PetConfig {
        guard !isProductPack(config.activePack) else { return config }
        var updated = config
        updated.activePack = preferredAgent.map(packID(for:)) ?? claudePackID
        return updated
    }

    static func isProductPack(_ packID: String) -> Bool {
        productPackIDs.contains(packID)
    }
}
