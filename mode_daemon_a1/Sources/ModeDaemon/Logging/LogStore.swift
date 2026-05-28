import Foundation
import Combine

struct WarningEvent: Identifiable, Codable {
    enum Kind: String, Codable {
        case memoryPressure
        case swapUsage
        case thermal
        case cpuSaturation
        case gpuUnavailable
    }
    
    let id: UUID
    let ts: Date
    let kind: Kind
    let message: String
    let mode: String
    
    init(kind: Kind, message: String, mode: PerformanceMode) {
        self.id = UUID()
        self.ts = Date()
        self.kind = kind
        self.message = message
        self.mode = mode.rawValue
    }
}

final class LogStore: ObservableObject {
    @Published private(set) var events: [WarningEvent] = []
    
    func append(_ event: WarningEvent) {
        DispatchQueue.main.async {
            self.events.insert(event, at: 0)
            if self.events.count > 500 {
                self.events.removeLast(self.events.count - 500)
            }
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.events.removeAll()
        }
    }
}

