import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar style app) while still allowing a window when opened from the menu.
        NSApp.setActivationPolicy(.accessory)
        
        statusBarController = StatusBarController(state: state)
        state.telemetry.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        state.telemetry.stop()
    }
}

