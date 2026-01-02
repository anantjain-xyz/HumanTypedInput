import SwiftUI
import HumanTypedInput

struct ContentView: View {
    @State private var metrics: TypingMetrics?
    @State private var confidenceScore: HumanConfidenceScore?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("HumanTypedInput Demo")
                    .font(.title)
                
                HumanTypedTextViewRepresentable(onMetricsUpdate: { newMetrics in
                    metrics = newMetrics
                    confidenceScore = HumanConfidenceScore(metrics: newMetrics)
                })
                .frame(height: 150)
                .padding(.horizontal)
                
                if let score = confidenceScore {
                    // Big score display
                    VStack(spacing: 8) {
                        Text("\(score.score)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(colorForScore(score.score))
                        
                        Text(score.interpretation)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Factor breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scoring Factors")
                            .font(.headline)
                        
                        ForEach(score.factors, id: \.name) { factor in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(factor.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(factor.score)")
                                        .foregroundColor(colorForScore(factor.score))
                                        .fontWeight(.bold)
                                }
                                Text(factor.explanation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Raw metrics
                    if let metrics = metrics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Raw Metrics")
                                .font(.headline)
                            
                            Text("Keystrokes: \(metrics.totalKeystrokes)")
                            Text("Deletions: \(metrics.deletionCount)")
                            if let avg = metrics.averageTimeBetweenKeys {
                                Text("Avg interval: \(String(format: "%.0f", avg * 1000))ms")
                            }
                            if let variance = metrics.timingVariance {
                                Text("Std deviation: \(String(format: "%.0f", variance * 1000))ms")
                            }
                            if let duration = metrics.sessionDuration {
                                Text("Session duration: \(String(format: "%.1f", duration))s")
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding(.top)
        }
    }
    
    func colorForScore(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 50...79: return .orange
        default: return .red
        }
    }
}

struct HumanTypedTextViewRepresentable: UIViewRepresentable {
    var onMetricsUpdate: (TypingMetrics) -> Void
    
    func makeUIView(context: Context) -> HumanTypedTextView {
        let textView = HumanTypedTextView()
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ uiView: HumanTypedTextView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onMetricsUpdate: onMetricsUpdate)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var onMetricsUpdate: (TypingMetrics) -> Void
        
        init(onMetricsUpdate: @escaping (TypingMetrics) -> Void) {
            self.onMetricsUpdate = onMetricsUpdate
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if let humanTypedView = textView as? HumanTypedTextView {
                onMetricsUpdate(humanTypedView.getTypingMetrics())
            }
        }
    }
}
