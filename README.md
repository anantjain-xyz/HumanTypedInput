# HumanTypedInput

An iOS Swift framework that detects whether text input was genuinely typed by a human or was pasted/automated. It captures keystroke timing metadata and analyzes typing dynamics to produce a confidence score.

| Human Typed | Copy-pasted slop |
| --- | --- |
| <video src="https://github.com/user-attachments/assets/7d98d8ab-da3a-488c-9e84-cfa88c38bfbb" width="300" autoplay loop muted></video> | <video src="https://github.com/user-attachments/assets/67cd8fb9-eae5-4ea3-b508-bd6d10fd3484" width="300" autoplay loop muted></video> |


## Who It's For

Product teams that need a lightweight, client-side signal for distinguishing human typing from paste/automation, such as account creation, feedback forms, or high-trust workflows.

## When Not to Use It

This should not be the only gate for security-sensitive decisions. Treat it as one signal among many (risk scoring, device signals, rate limits, etc.).

## Features

- Real-time keystroke capture with sub-millisecond precision
- Multi-factor analysis (timing variance, typing speed, corrections, burst detection)
- Confidence score from 0-100 with human-readable interpretation
- Export typing proof as JSON for backend verification

## Installation

This is an Xcode project (no package manager).

1. Open `HumanTypedInput.xcodeproj`.
2. Add the `HumanTypedInput` framework to your app target in "Frameworks, Libraries, and Embedded Content".
3. Import `HumanTypedInput` in your app code.

If you prefer, you can also build and integrate the framework output manually.

## Demo App

Open the project in Xcode and run the `HumanTypedInputDemo` scheme, or build via:

```bash
xcodebuild -project HumanTypedInput.xcodeproj -scheme HumanTypedInputDemo -sdk iphonesimulator
```

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
let proof = textView.exportTypingProof()
let jsonData = try proof.toJSONData()

// Or get as string
let jsonString = try proof.toJSONString()
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
  }
}
```

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

## Privacy & Data Handling

- The SDK does not perform network requests.
- Metrics are stored in memory during a session.
- Exported JSON is only created when you explicitly call `exportTypingProof()`.

## Limitations

- Confidence scores depend on sample size and context; fewer than ~30 keystrokes may be unreliable.
- Input method differences (predictive text, accessibility tools, hardware keyboards) can affect timing patterns.

## Support

Please use GitHub Issues for bugs and feature requests. For security issues, see `SECURITY.md`.

## License

MIT. See `LICENSE`.
