import Foundation
import Combine

final class TelemetrySampler: ObservableObject {
    @Published private(set) var metrics: SystemMetrics = SystemMetrics(
        cpuTotalPct: 0,
        memUsedPct: 0,
        memFreeMB: 0,
        swapUsedMB: 0,
        thermalState: ProcessInfo.processInfo.thermalState,
        gpuUtilizationPct: nil
    )
    
    var onWarning: ((WarningEvent) -> Void)?
    
    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval
    private var prevCPU: CPUUsage.Snapshot?
    
    init(initialInterval: TimeInterval) {
        self.interval = initialInterval
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    func setSamplingInterval(_ seconds: TimeInterval) {
        interval = max(0.5, seconds)
        if timer != nil {
            stop()
            start()
        }
    }
    
    func start() {
        if timer != nil { return }
        
        // Prime CPU snapshot for delta calculations.
        prevCPU = CPUUsage.readSnapshot()
        
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in
            self?.sample()
        }
        t.resume()
        timer = t
        
        // Log once: GPU metrics not available.
        onWarning?(WarningEvent(kind: .gpuUnavailable, message: "GPU utilization metrics are not available via public APIs; use Instruments/Metal System Trace for deep GPU counters.", mode: .normal))
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
    
    @objc private func thermalChanged() {
        // Thermal state will be read on next sample; this is just to wake UI if needed.
        DispatchQueue.main.async {
            self.metrics.thermalState = ProcessInfo.processInfo.thermalState
        }
    }
    
    private func sample() {
        let thermal = ProcessInfo.processInfo.thermalState
        
        // CPU
        let cpuPct: Double = {
            guard let prev = prevCPU, let cur = CPUUsage.readSnapshot() else { return metrics.cpuTotalPct }
            prevCPU = cur
            return CPUUsage.totalUsagePercent(prev: prev, cur: cur)
        }()
        
        // Memory
        let (memUsedPct, memFreeMB): (Double, Double) = {
            guard let mem = MemoryStats.readSnapshot() else { return (metrics.memUsedPct, metrics.memFreeMB) }
            return (MemoryStats.usedPercent(mem), MemoryStats.freeMB(mem))
        }()
        
        // Swap
        let swapUsedMB: Double = MemoryStats.readSwapUsage()?.usedMB ?? metrics.swapUsedMB
        
        let updated = SystemMetrics(
            cpuTotalPct: cpuPct,
            memUsedPct: memUsedPct,
            memFreeMB: memFreeMB,
            swapUsedMB: swapUsedMB,
            thermalState: thermal,
            gpuUtilizationPct: nil
        )
        
        DispatchQueue.main.async {
            self.metrics = updated
        }
        
        // Warnings are mode-dependent; we attach mode at emission time in UI.
        // The UI calls `evaluateWarnings(mode:)` each time it renders.
    }
    
    func evaluateWarnings(mode: PerformanceMode) -> [WarningEvent] {
        let t = mode.thresholds
        var out: [WarningEvent] = []
        
        if Int(metrics.cpuTotalPct.rounded()) >= t.cpuWarnPct {
            out.append(WarningEvent(kind: .cpuSaturation, message: "High CPU load (\(Int(metrics.cpuTotalPct))%). This can starve GPU submission and cause stutters/slowdowns.", mode: mode))
        }
        
        if Int(metrics.swapUsedMB.rounded()) >= t.swapUsedWarnMB {
            out.append(WarningEvent(kind: .swapUsage, message: "Swap used is high (~\(Int(metrics.swapUsedMB)) MB). Unified memory pressure can cause big performance cliffs for games/LLMs.", mode: mode))
        }
        
        if metrics.thermalState.rawValue >= t.thermalWarnState.rawValue {
            out.append(WarningEvent(kind: .thermal, message: "Thermal pressure is \(metrics.thermalState). Sustained performance may be throttled.", mode: mode))
        }
        
        return out
    }
}

