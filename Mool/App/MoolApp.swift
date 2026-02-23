import SwiftUI

@main
struct MoolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Library window — shown on demand
        WindowGroup("Library", id: "library") {
            LibraryView()
                .environment(appDelegate.storageManager)
                .environment(appDelegate.recordingEngine)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Settings window
        Settings {
            SettingsView()
                .environment(appDelegate.recordingEngine)
                .environment(appDelegate.storageManager)
        }
    }
}
