import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var mode: PerformanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "mode")
            telemetry.setSamplingInterval(mode.samplingInterval)
        }
    }
    
    let telemetry: TelemetrySampler
    let logs: LogStore
    
    init() {
        let raw = UserDefaults.standard.string(forKey: "mode") ?? PerformanceMode.normal.rawValue
        self.mode = PerformanceMode(rawValue: raw) ?? .normal
        self.logs = LogStore()
        self.telemetry = TelemetrySampler(initialInterval: self.mode.samplingInterval)
        self.telemetry.onWarning = { [weak self] warning in
            self?.logs.append(warning)
        }
    }
}

