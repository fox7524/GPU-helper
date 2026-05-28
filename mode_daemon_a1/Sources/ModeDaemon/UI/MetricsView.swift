import SwiftUI

struct MetricsView: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Metrics").font(.headline)
            HStack(spacing: 16) {
                MetricCard(title: "CPU", value: "\(Int(metrics.cpuTotalPct))%", subtitle: "Total usage")
                MetricCard(title: "Memory", value: "\(Int(metrics.memUsedPct))%", subtitle: String(format: "Free %.0f MB", metrics.memFreeMB))
                MetricCard(title: "Swap Used", value: "\(Int(metrics.swapUsedMB)) MB", subtitle: "Higher = risk")
                MetricCard(title: "Thermal", value: thermalLabel(metrics.thermalState), subtitle: "Pressure state")
                MetricCard(title: "GPU", value: gpuLabel(metrics.gpuUtilizationPct), subtitle: "Public API: limited")
            }
        }
    }
    
    private func thermalLabel(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private func gpuLabel(_ v: Double?) -> String {
        guard let v else { return "Unavailable" }
        return "\(Int(v))%"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title3).monospacedDigit()
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(minWidth: 130, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
    }
}

