import SwiftUI
import HumanTypedInput

struct ContentView: View {
    @State private var metrics: TypingMetrics?
    @State private var confidenceScore: HumanConfidenceScore?
    @State private var textView: HumanTypedTextView?
    @State private var showingExportSheet = false
    @State private var exportedJSON: String = ""
    @State private var selectedExportOption = 0

    private let exportOptions = ["Standard", "Minimal", "Redacted", "Full"]

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

                        Picker("Export Option", selection: $selectedExportOption) {
                            ForEach(0..<exportOptions.count, id: \.self) { index in
                                Text(exportOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)

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
        .sheet(isPresented: $showingExportSheet) {
            ExportSheetView(json: exportedJSON)
        }
    }

    private func exportProof() {
        guard let textView = textView else { return }

        let options: TypingProofExportOptions
        switch selectedExportOption {
        case 0: options = .standard
        case 1: options = .minimal
        case 2: options = .redacted
        case 3: options = .full
        default: options = .standard
        }

        do {
            exportedJSON = try textView.exportTypingProof(options: options).toJSONString()
            showingExportSheet = true
        } catch {
            exportedJSON = "Error: \(error.localizedDescription)"
            showingExportSheet = true
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
