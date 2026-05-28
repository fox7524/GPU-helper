import Foundation

struct SystemMetrics: Codable {
    var cpuTotalPct: Double
    var memUsedPct: Double
    var memFreeMB: Double
    var swapUsedMB: Double
    var thermalState: ProcessInfo.ThermalState
    
    // Currently no reliable public API for global GPU utilization.
    var gpuUtilizationPct: Double?
}

