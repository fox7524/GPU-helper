import SwiftUI

struct WarningsView: View {
    let warnings: [WarningEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Warnings").font(.headline)
                Spacer()
                Text(warnings.isEmpty ? "OK" : "\(warnings.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(warnings.isEmpty ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
            }
            
            if warnings.isEmpty {
                Text("No warnings for the current mode thresholds.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(warnings) { w in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color(for: w.kind))
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(for: w.kind)).font(.subheadline).bold()
                            Text(w.message).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .underPageBackgroundColor)))
                }
            }
        }
    }
    
    private func title(for kind: WarningEvent.Kind) -> String {
        switch kind {
        case .memoryPressure: return "Memory pressure"
        case .swapUsage: return "Swap usage"
        case .thermal: return "Thermal pressure"
        case .cpuSaturation: return "CPU saturation"
        case .gpuUnavailable: return "GPU metrics"
        }
    }
    
    private func color(for kind: WarningEvent.Kind) -> Color {
        switch kind {
        case .thermal: return .red
        case .swapUsage: return .orange
        case .memoryPressure: return .orange
        case .cpuSaturation: return .orange
        case .gpuUnavailable: return .blue
        }
    }
}

