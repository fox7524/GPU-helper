import SwiftUI

@main
struct ModeDaemonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        // We keep a Settings scene so the app can show a proper window when needed,
        // but the primary UI is a menu bar status item.
        Settings {
            ContentView()
                .environmentObject(appDelegate.state)
        }
    }
}

