struct PanelInteractionPolicy: Equatable, Sendable {
    enum PrimaryClickAction: Equatable, Sendable {
        case pet
        case openSettings
    }

    enum SettingsEntryPoint: Equatable, Sendable {
        case menuBar
        case panelClick
    }

    let primaryClickAction: PrimaryClickAction
    let settingsEntryPoint: SettingsEntryPoint

    static let `default` = PanelInteractionPolicy(
        primaryClickAction: .pet,
        settingsEntryPoint: .menuBar
    )
}
