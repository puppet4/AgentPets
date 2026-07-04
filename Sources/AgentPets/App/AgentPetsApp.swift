import SwiftUI
import AppKit

@main
struct AgentPetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main scene — app runs as .accessory (no Dock icon, no menu bar entry).
        // The Touch Bar is provided by NSApplicationDelegate.makeTouchBar().
        Settings {
            EmptyView()
        }
    }
}
