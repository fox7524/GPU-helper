## Patch snippets (apply to your fork)

These are the minimal edits needed to wire modes into Stats.

### A) `Kit/types.swift`

1) Add a new notification name:
```swift
public extension Notification.Name {
    // ...
    static let performanceModeChanged = Notification.Name("performanceModeChanged")
    static let performanceModeMenuBarVisibilityChanged = Notification.Name("performanceModeMenuBarVisibilityChanged")
}
```

2) Add the `PerformanceMode` enum + picker items (place near the notification names):
```swift
public enum PerformanceMode: String, Codable, CaseIterable {
    case normal
    case llm
    case game

    public var title: String {
        switch self {
        case .normal: return "Normal"
        case .llm: return "LLM"
        case .game: return "Game"
        }
    }
}

public let PerformanceModes: [KeyValue_t] = [
    KeyValue_t(key: PerformanceMode.normal.rawValue, value: PerformanceMode.normal.title),
    KeyValue_t(key: PerformanceMode.llm.rawValue, value: PerformanceMode.llm.title),
    KeyValue_t(key: PerformanceMode.game.rawValue, value: PerformanceMode.game.title)
]
```

### B) `Stats/Views/AppSettings.swift`

Add:
- stored value `performance_mode`
- optional bool `performance_mode_menubar`
- selector UI + “Save current layout to this mode”
- “Show mode in menu bar” switch
- handlers to set mode + save snapshot

Key handlers:
```swift
@objc private func togglePerformanceMode(_ sender: NSMenuItem) {
    guard let key = sender.representedObject as? String,
          let mode = PerformanceMode(rawValue: key) else { return }
    PerformanceModeManager.setMode(mode)
}

@objc private func saveModeLayout() {
    guard let mode = PerformanceMode(rawValue: Store.shared.string(key: "performance_mode", defaultValue: "normal")) else { return }
    PerformanceModeManager.saveSnapshot(for: mode, modules: modules)
}

@objc private func toggleModeMenuBar(_ sender: NSButton) {
    Store.shared.set(key: "performance_mode_menubar", value: sender.state == .on)
    NotificationCenter.default.post(name: .performanceModeMenuBarVisibilityChanged, object: nil)
}
```

### C) `Stats/AppDelegate.swift`

1) Apply mode snapshot after modules mount:
```swift
self.setup {
    modules.reversed().forEach{ $0.mount() }
    PerformanceModeManager.applySnapshot(for: PerformanceModeManager.currentMode, modules: modules)
    self.showSettingsIfNoActiveWidgets()
}
```

2) Listen for the mode change notification:
```swift
NotificationCenter.default.addObserver(self, selector: #selector(handlePerformanceModeChanged(_:)), name: .performanceModeChanged, object: nil)
```

3) Handler:
```swift
@objc private func handlePerformanceModeChanged(_ notification: Notification) {
    PerformanceModeManager.applySnapshot(for: PerformanceModeManager.currentMode, modules: modules)
    self.updateModeStatusItem()
}
```

4) Add menu bar indicator implementation (UI-only):
- add property `modeStatusItem: NSStatusItem?`
- create/remove it based on `performance_mode_menubar` key
- show a small menu to pick modes

### D) Add file to Xcode project

Add `Stats/PerformanceModeManager.swift` to the **Stats** target in Xcode (drag & drop into the project navigator and ensure the target membership checkbox is on).
