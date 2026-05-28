import SwiftUI

struct LogsView: View {
    let events: [WarningEvent]
    let onClear: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Event Log").font(.headline)
                Spacer()
                Button("Clear") { onClear() }
            }
            
            if events.isEmpty {
                Text("No events yet. Leave it running while you game or run LM Studio.")
                    .foregroundStyle(.secondary)
            } else {
                List(events) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(e.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(e.ts.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(e.message)
                            .font(.callout)
                        Text("mode=\(e.mode)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 180)
            }
        }
    }
}

