//
//  PerformanceModeManager.swift
//  Stats
//
//  Adds manual UI "modes" (Normal/LLM/Game) that instantly apply a saved layout snapshot.
//  No automatic system changes; this only toggles Stats' own modules/widgets visibility.
//

import Foundation
import Kit

internal struct ModeSnapshot: Codable {
    /// Module name -> enabled state
    var moduleStates: [String: Bool]
    
    /// Module name -> raw widget list string (same format as Store key "<Module>_widget")
    var widgetLists: [String: String]
    
    /// Module name -> widget rawValue -> position
    var widgetPositions: [String: [String: Int]]
    
    init(moduleStates: [String: Bool], widgetLists: [String: String], widgetPositions: [String: [String: Int]]) {
        self.moduleStates = moduleStates
        self.widgetLists = widgetLists
        self.widgetPositions = widgetPositions
    }
}

internal enum PerformanceModeManager {
    private static let modeKey = "performance_mode"
    private static let snapshotKeyPrefix = "performance_mode_snapshot_"
    
    static var currentMode: PerformanceMode {
        let raw = Store.shared.string(key: modeKey, defaultValue: PerformanceMode.normal.rawValue)
        return PerformanceMode(rawValue: raw) ?? .normal
    }
    
    static func setMode(_ mode: PerformanceMode) {
        Store.shared.set(key: modeKey, value: mode.rawValue)
        NotificationCenter.default.post(name: .performanceModeChanged, object: nil, userInfo: ["mode": mode.rawValue])
    }
    
    static func saveSnapshot(for mode: PerformanceMode, modules: [Module]) {
        var states: [String: Bool] = [:]
        var widgetLists: [String: String] = [:]
        var widgetPositions: [String: [String: Int]] = [:]
        
        for m in modules where m.available {
            states[m.config.name] = m.enabled
            widgetLists[m.config.name] = Store.shared.string(key: "\(m.config.name)_widget", defaultValue: m.config.defaultWidget.rawValue)
            
            var positions: [String: Int] = [:]
            for w in m.menuBar.widgets {
                positions[w.type.rawValue] = Store.shared.int(key: "\(m.config.name)_\(w.type)_position", defaultValue: 0)
            }
            widgetPositions[m.config.name] = positions
        }
        
        let snapshot = ModeSnapshot(moduleStates: states, widgetLists: widgetLists, widgetPositions: widgetPositions)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        Store.shared.set(key: snapshotKeyPrefix + mode.rawValue, value: data)
    }
    
    static func loadSnapshot(for mode: PerformanceMode) -> ModeSnapshot? {
        guard let data = Store.shared.data(key: snapshotKeyPrefix + mode.rawValue) else { return nil }
        return try? JSONDecoder().decode(ModeSnapshot.self, from: data)
    }
    
    /// Apply the saved snapshot for the given mode (if it exists).
    /// This only changes Stats internal layout: module enabled states + widgets.
    static func applySnapshot(for mode: PerformanceMode, modules: [Module]) {
        guard let snapshot = loadSnapshot(for: mode) else { return }
        
        // 1) Apply module enabled states.
        for m in modules where m.available {
            guard let desiredEnabled = snapshot.moduleStates[m.config.name] else { continue }
            if desiredEnabled != m.enabled {
                NotificationCenter.default.post(
                    name: .toggleModule,
                    object: nil,
                    userInfo: ["module": m.config.name, "state": desiredEnabled]
                )
            }
        }
        
        // 2) Apply widget positions first (so layout is stable when widgets appear).
        for (moduleName, positions) in snapshot.widgetPositions {
            for (widgetRaw, pos) in positions {
                Store.shared.set(key: "\(moduleName)_\(widgetRaw)_position", value: pos)
            }
        }
        
        // 3) Apply widget active lists.
        for m in modules where m.available {
            guard let listRaw = snapshot.widgetLists[m.config.name] else { continue }
            let desired: [widget_t] = listRaw
                .split(separator: ",")
                .map { widget_t(rawValue: String($0)) ?? .unknown }
                .filter { $0 != .unknown }
            
            // Persist list in store (so it's consistent with the UI).
            Store.shared.set(key: "\(m.config.name)_widget", value: desired.map { $0.rawValue }.joined(separator: ","))
            
            // Toggle widgets to match.
            for w in m.menuBar.widgets {
                let shouldBeActive = desired.contains(w.type)
                if w.isActive != shouldBeActive {
                    w.toggle(shouldBeActive)
                }
            }
            
            // Ask menu bar to recalculate ordering.
            NotificationCenter.default.post(
                name: .widgetRearrange,
                object: nil,
                userInfo: ["module": m.config.name]
            )
        }
    }
}

