import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var lastWarningEmit: Date = .distantPast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ModeDaemon Dashboard")
                    .font(.title2)
                Spacer()
                Picker("Mode", selection: $state.mode) {
                    ForEach(PerformanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            MetricsView(metrics: state.telemetry.metrics)
            
            WarningsView(warnings: state.telemetry.evaluateWarnings(mode: state.mode))
                .onAppear { emitWarningsIfNeeded() }
                .onChange(of: state.telemetry.metrics) { _ in emitWarningsIfNeeded() }
                .onChange(of: state.mode) { _ in emitWarningsIfNeeded(force: true) }
            
            Divider()
            
            LogsView(events: state.logs.events) {
                state.logs.clear()
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
    }
    
    private func emitWarningsIfNeeded(force: Bool = false) {
        // Emit warning events at most once every ~10 seconds to avoid log spam.
        let now = Date()
        if !force && now.timeIntervalSince(lastWarningEmit) < 10 { return }
        lastWarningEmit = now
        
        for w in state.telemetry.evaluateWarnings(mode: state.mode) {
            state.logs.append(w)
        }
    }
}

