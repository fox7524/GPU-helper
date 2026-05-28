import Foundation
import Darwin.Mach

enum MemoryStats {
    struct Snapshot {
        var pageSize: UInt64
        var free: UInt64
        var active: UInt64
        var inactive: UInt64
        var wired: UInt64
        var compressed: UInt64
        var total: UInt64
    }
    
    struct SwapUsageMB {
        var usedMB: Double
        var totalMB: Double
    }
    
    static func readSnapshot() -> Snapshot? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
        
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        
        // Total physical memory
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        
        return Snapshot(
            pageSize: UInt64(pageSize),
            free: UInt64(vmStat.free_count),
            active: UInt64(vmStat.active_count),
            inactive: UInt64(vmStat.inactive_count),
            wired: UInt64(vmStat.wire_count),
            compressed: UInt64(vmStat.compressor_page_count),
            total: memSize / UInt64(pageSize)
        )
    }
    
    static func readSwapUsage() -> SwapUsageMB? {
        // vm.swapusage is a struct xsw_usage. We'll define a matching Swift struct.
        struct XSWUsage {
            var total: UInt64
            var avail: UInt64
            var used: UInt64
            var pagesize: UInt32
            var encrypted: UInt32
        }
        
        var xsw = XSWUsage(total: 0, avail: 0, used: 0, pagesize: 0, encrypted: 0)
        var size = MemoryLayout<XSWUsage>.size
        let res = sysctlbyname("vm.swapusage", &xsw, &size, nil, 0)
        guard res == 0 else { return nil }
        
        let usedMB = Double(xsw.used) / 1024.0 / 1024.0
        let totalMB = Double(xsw.total) / 1024.0 / 1024.0
        return SwapUsageMB(usedMB: usedMB, totalMB: totalMB)
    }
    
    static func usedPercent(_ snap: Snapshot) -> Double {
        // "Used" = total - free (rough), but we expose free MB too.
        let totalBytes = Double(snap.total) * Double(snap.pageSize)
        let freeBytes = Double(snap.free) * Double(snap.pageSize)
        let usedBytes = max(0, totalBytes - freeBytes)
        return max(0, min(100, usedBytes / max(totalBytes, 1) * 100))
    }
    
    static func freeMB(_ snap: Snapshot) -> Double {
        Double(snap.free) * Double(snap.pageSize) / 1024.0 / 1024.0
    }
}

