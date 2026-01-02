# HumanTypedInput

An iOS Swift framework that detects whether text input was genuinely typed by a human or was pasted/automated. It captures keystroke timing metadata and analyzes typing dynamics to produce a confidence score.

## Features

- Real-time keystroke capture with sub-millisecond precision
- Multi-factor analysis (timing variance, typing speed, corrections, burst detection)
- Confidence score from 0-100 with human-readable interpretation
- Export typing proof as JSON for backend verification
- Privacy-friendly options (redact characters, minimal export)

## Installation

Add the `HumanTypedInput` framework to your Xcode project.

## Basic Usage

### 1. Capture Typing

Use `HumanTypedTextView` instead of `UITextView`:

```swift
import HumanTypedInput

let textView = HumanTypedTextView()
// Use like a regular UITextView
```

### 2. Get Confidence Score

```swift
let metrics = textView.getTypingMetrics()
let score = HumanConfidenceScore(metrics: metrics)

print(score.score)          // 0-100
print(score.interpretation) // "High confidence: likely human typed"
```

### 3. Reset Between Sessions

```swift
textView.resetSession()
```

## Exporting Typing Proof

Export captured data as JSON to send to your backend for verification:

```swift
// Standard export (includes raw keystroke events)
let proof = textView.exportTypingProof()
let jsonData = try proof.toJSONData()

// Or get as string
let jsonString = try proof.toJSONString()
```

### Export Options

| Preset | Description |
|--------|-------------|
| `.default` | Raw keystroke events + content hash (default) |
| `.minimal` | Metrics + confidence only (smallest payload) |
| `.redacted` | Raw events with characters replaced by `*` + content hash |

```swift
// Minimal export for bandwidth-constrained scenarios
let minimal = textView.exportTypingProof(options: .minimal)

// Redacted export for maximum privacy
let redacted = textView.exportTypingProof(options: .redacted)

// Custom options
var options = TypingProofExportOptions()
options.includeRawEvents = true
options.redactCharacters = true
options.includeContentVerification = false
let custom = textView.exportTypingProof(options: options)
```

### JSON Structure

```json
{
  "version": "1.0",
  "metadata": {
    "exportedAt": "2024-01-15T10:30:00.000Z",
    "sessionStartedAt": "2024-01-15T10:25:00.000Z",
    "sessionDurationMs": 300000,
    "sdkVersion": "1.0.0",
    "platform": "iOS",
    "platformVersion": "17.0"
  },
  "metrics": {
    "totalKeystrokes": 156,
    "deletionCount": 12,
    "correctionRate": 0.077,
    "averageIntervalMs": 185.4,
    "timingVarianceMs": 72.3,
    "estimatedWPM": 54
  },
  "confidence": {
    "score": 87,
    "interpretation": "High confidence: likely human typed",
    "factors": [
      {"name": "Sample Volume", "score": 100, "weight": 0.10, "explanation": "..."},
      {"name": "Timing Variance", "score": 95, "weight": 0.25, "explanation": "..."},
      {"name": "Typing Speed", "score": 100, "weight": 0.20, "explanation": "..."},
      {"name": "Correction Rate", "score": 85, "weight": 0.20, "explanation": "..."},
      {"name": "Burst Detection", "score": 100, "weight": 0.25, "explanation": "..."}
    ]
  },
  "events": [
    {"index": 0, "timestampMs": 0, "character": "H", "intervalMs": null},
    {"index": 1, "timestampMs": 187, "character": "e", "intervalMs": 187},
    {"index": 2, "timestampMs": 342, "character": "l", "intervalMs": 155}
  ],
  "content": {
    "length": 142,
    "sha256": "a1b2c3d4..."
  }
}
```

Notes:
- `events` is `null` when using `.minimal`
- `events[].character` is `"*"` when using `.redacted` (except `"[DELETE]"`)
- `content` is `null` unless using `.full` or `includeContentVerification: true`

## Score Interpretation

| Score | Interpretation |
|-------|----------------|
| 80-100 | High confidence: likely human typed |
| 50-79 | Medium confidence: possibly human typed |
| 20-49 | Low confidence: suspicious pattern |
| 0-19 | Very low confidence: likely pasted or automated |

## Scoring Factors

| Factor | Weight | What it measures |
|--------|--------|------------------|
| Sample Volume | 10% | Needs 30+ keystrokes for reliable analysis |
| Timing Variance | 25% | Humans have inconsistent timing (CV 0.3-0.8) |
| Typing Speed | 20% | Normal is 30-80 WPM; >200 WPM is suspicious |
| Correction Rate | 20% | Humans make mistakes (5-20% deletions is normal) |
| Burst Detection | 25% | Intervals <20ms are impossible for humans |

## Requirements

- iOS 14.0+
- Swift 5.0+

## License

MIT
