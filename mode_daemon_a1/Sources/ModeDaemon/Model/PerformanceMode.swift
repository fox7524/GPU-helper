import Foundation

enum PerformanceMode: String, CaseIterable, Identifiable, Codable {
    case normal
    case llm
    case game
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .llm: return "LLM"
        case .game: return "Game"
        }
    }
    
    /// Sampling interval per mode (seconds). We keep this conservative for battery/overhead.
    var samplingInterval: TimeInterval {
        switch self {
        case .normal: return 2.0
        case .llm: return 1.0
        case .game: return 1.0
        }
    }
    
    /// Thresholds per mode. These are for warnings only; they do not change system state.
    var thresholds: Thresholds {
        switch self {
        case .normal:
            return Thresholds(
                cpuWarnPct: 90,
                swapUsedWarnMB: 1024,
                thermalWarnState: .serious
            )
        case .llm:
            return Thresholds(
                cpuWarnPct: 85,
                swapUsedWarnMB: 512,
                thermalWarnState: .serious
            )
        case .game:
            return Thresholds(
                cpuWarnPct: 85,
                swapUsedWarnMB: 256,
                thermalWarnState: .serious
            )
        }
    }
}

struct Thresholds: Codable {
    var cpuWarnPct: Int
    var swapUsedWarnMB: Int
    var thermalWarnState: ProcessInfo.ThermalState
}

