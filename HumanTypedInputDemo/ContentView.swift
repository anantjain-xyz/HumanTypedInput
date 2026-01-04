import SwiftUI
import Charts
import HumanTypedInput

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    @State private var metrics: TypingMetrics?
    @State private var confidenceScore: HumanConfidenceScore?
    @State private var textView: HumanTypedTextView?
    @State private var exportedJSON: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("HumanTypedInput Demo")
                    .font(.title)
                
                HumanTypedTextViewRepresentable(
                    onMetricsUpdate: { newMetrics in
                        metrics = newMetrics
                        confidenceScore = HumanConfidenceScore(metrics: newMetrics)
                    },
                    onTextViewCreated: { view in
                        textView = view
                    }
                )
                .frame(height: 150)
                .padding(.horizontal)

                // Typing rhythm chart
                TypingRhythmChart(events: metrics?.events ?? [])
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

                    // Export section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Typing Proof")
                            .font(.headline)

                        Button(action: exportProof) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export as JSON")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
        .sheet(item: $exportedJSON) { json in
            ExportSheetView(json: json)
        }
    }

    private func exportProof() {
        guard let textView = textView else { return }

        do {
            exportedJSON = try textView.exportTypingProof().toJSONString()
        } catch {
            exportedJSON = "Error: \(error.localizedDescription)"
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
    var onTextViewCreated: (HumanTypedTextView) -> Void

    func makeUIView(context: Context) -> HumanTypedTextView {
        let textView = HumanTypedTextView()
        textView.delegate = context.coordinator
        DispatchQueue.main.async {
            onTextViewCreated(textView)
        }
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

// MARK: - Export Sheet View

struct ExportSheetView: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Typing Proof JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = json
    }
}

// MARK: - Typing Rhythm Chart

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let index: Int
    let intervalMs: Double
    let isDelete: Bool
    let isBurst: Bool
}

struct TypingRhythmChart: View {
    let events: [KeystrokeEvent]

    private let burstThresholdMs: Double = 20

    private var chartData: [ChartDataPoint] {
        events.enumerated().compactMap { index, event -> ChartDataPoint? in
            guard let interval = event.timeSincePreviousKey else { return nil }
            let intervalMs = interval * 1000
            return ChartDataPoint(
                index: index,
                intervalMs: min(intervalMs, 500), // Cap at 500ms for readability
                isDelete: event.character == "[DELETE]",
                isBurst: interval < 0.020
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Typing Rhythm")
                .font(.headline)

            if chartData.isEmpty {
                Text("Start typing to see rhythm visualization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Burst threshold reference line
                    RuleMark(y: .value("Burst Threshold", burstThresholdMs))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.red.opacity(0.5))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("20ms")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.7))
                        }

                    // Line connecting points
                    ForEach(chartData) { point in
                        LineMark(
                            x: .value("Keystroke", point.index),
                            y: .value("Interval", point.intervalMs)
                        )
                        .foregroundStyle(.blue.opacity(0.6))
                    }

                    // Points with color coding
                    ForEach(chartData) { point in
                        PointMark(
                            x: .value("Keystroke", point.index),
                            y: .value("Interval", point.intervalMs)
                        )
                        .foregroundStyle(pointColor(for: point))
                        .symbol(point.isDelete ? .triangle : .circle)
                        .symbolSize(point.isDelete ? 60 : 40)
                    }
                }
                .chartYAxisLabel("Interval (ms)")
                .chartXAxisLabel("Keystroke #")
                .chartYScale(domain: 0...500)
                .frame(height: 180)
            }

            // Legend
            HStack(spacing: 16) {
                Label("Normal", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Label("Burst (<20ms)", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                Label("Deletion", systemImage: "triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func pointColor(for point: ChartDataPoint) -> Color {
        if point.isBurst {
            return .red
        } else if point.isDelete {
            return .orange
        } else {
            return .blue
        }
    }
}
