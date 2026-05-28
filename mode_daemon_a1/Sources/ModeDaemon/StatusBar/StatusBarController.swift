import AppKit
import SwiftUI

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let state: AppState
    
    init(state: AppState) {
        self.state = state
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "ModeDaemon")
            button.imagePosition = .imageLeft
            button.title = "Mode"
        }
        
        statusItem.menu = makeMenu()
        
        // Rebuild menu when mode changes (so checkmarks update).
        _ = state.$mode.sink { [weak self] _ in
            self?.statusItem.menu = self?.makeMenu()
        }
    }
    
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        
        let header = NSMenuItem(title: "ModeDaemon", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        
        // Mode selection
        for m in PerformanceMode.allCases {
            let item = NSMenuItem(title: m.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = m.rawValue
            item.state = (m == state.mode) ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        let open = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        
        let clear = NSMenuItem(title: "Clear Logs", action: #selector(clearLogs), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        
        menu.addItem(.separator())
        
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        
        return menu
    }
    
    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let m = PerformanceMode(rawValue: raw) else { return }
        state.mode = m
    }
    
    @objc private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        // Open the Settings scene window (we reuse it as a dashboard window).
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc private func clearLogs() {
        state.logs.clear()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

