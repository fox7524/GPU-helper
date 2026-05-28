import Foundation
import Darwin.Mach

enum CPUUsage {
    struct Snapshot {
        var user: UInt64
        var system: UInt64
        var idle: UInt64
        var nice: UInt64
    }
    
    static func readSnapshot() -> Snapshot? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPtr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        return Snapshot(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }
    
    static func totalUsagePercent(prev: Snapshot, cur: Snapshot) -> Double {
        let prevTotal = prev.user + prev.system + prev.idle + prev.nice
        let curTotal = cur.user + cur.system + cur.idle + cur.nice
        let totalDelta = Double(max(curTotal &- prevTotal, 0))
        
        let idleDelta = Double(max(cur.idle &- prev.idle, 0))
        if totalDelta <= 0 { return 0 }
        return max(0, min(100, (1.0 - idleDelta / totalDelta) * 100.0))
    }
}

