# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HumanTypedInput** is an iOS Swift framework that detects whether text input was genuinely typed by a human or was pasted/automated. It captures keystroke timing metadata and analyzes typing dynamics to produce a confidence score.

The framework consists of two main components:
- **HumanTypedInput framework**: The core library with keystroke capture and analysis
- **HumanTypedInputDemo app**: A SwiftUI demo app showing real-time analysis

## Build Commands

This is an Xcode project with two targets:

```bash
# Build the framework
xcodebuild -project HumanTypedInput.xcodeproj -scheme HumanTypedInput -sdk iphoneos

# Build the demo app
xcodebuild -project HumanTypedInput.xcodeproj -scheme HumanTypedInputDemo -sdk iphoneos

# Build for simulator
xcodebuild -project HumanTypedInput.xcodeproj -scheme HumanTypedInputDemo -sdk iphonesimulator

# Clean build
xcodebuild clean -project HumanTypedInput.xcodeproj
```

Alternatively, open `HumanTypedInput.xcodeproj` in Xcode and use Cmd+B to build.

## Architecture

### Core Data Flow

1. **Input Capture** (`HumanTypedTextView` in HumanTypedInput.swift:24-121)
   - Subclass of `UITextView` that intercepts `insertText(_:)` and `deleteBackward()`
   - Captures each keystroke with high-precision timing using `CACurrentMediaTime()`
   - Records timestamp, character, and time-since-previous-key for every event
   - Deletions are tracked as special `[DELETE]` character events

2. **Metric Calculation** (`TypingMetrics` in TypingMetrics.swift:12-64)
   - Aggregates raw keystroke events into statistical metrics
   - Calculates: average inter-keystroke interval, standard deviation, session duration
   - Computes correction rate (ratio of deletions to total keystrokes)
   - All timing uses `TimeInterval` (seconds as Double)

3. **Human Confidence Scoring** (`HumanConfidenceScore` in HumanConfidenceScore.swift:12-243)
   - Multi-factor analysis producing a 0-100 confidence score
   - Five independent scoring factors with explanations:
     - **Sample Volume**: Requires 30+ keystrokes for high confidence
     - **Timing Variance**: Humans are inconsistent (coefficient of variation 0.3-0.8 is ideal)
     - **Typing Speed**: 30-80 WPM is normal; >200 WPM is suspiciously fast
     - **Correction Rate**: 5-20% deletions is typical; 0% is suspicious
     - **Burst Detection**: Intervals <20ms are near-impossible for humans
   - Uses weighted average: `[0.1, 0.25, 0.2, 0.2, 0.25]` for each factor

### Key Design Decisions

- **High-precision timing**: Uses `CACurrentMediaTime()` instead of `Date()` for monotonic, sub-millisecond accuracy
- **Statistical thresholds**: All ranges (WPM, variance, etc.) are heuristic-based and may need tuning with real-world data
- **Progressive confidence**: Low keystroke counts result in capped scores, even if patterns look human
- **Deletion tracking**: Captures backspace events since humans naturally make corrections

## File Structure

```
HumanTypedInput/               # Framework module
├── HumanTypedInput.swift      # Main UITextView subclass + KeystrokeEvent struct
├── TypingMetrics.swift        # Statistical analysis struct
├── HumanConfidenceScore.swift # Multi-factor scoring algorithm
└── HumanTypedInput.docc/      # DocC documentation (currently placeholder)

HumanTypedInputDemo/           # SwiftUI demo app
├── HumanTypedInputDemoApp.swift
├── ContentView.swift          # Real-time UI showing score + factors + raw metrics
└── Item.swift

HumanTypedInput.xcodeproj/     # Xcode project
```

## Development Notes

### When modifying scoring algorithm (HumanConfidenceScore.swift):
- Each scoring function returns a `ScoringFactor` with score (0-100) and explanation
- Weights in line 67 must sum to 1.0
- Volume score acts as a gating factor (line 63-66) - insufficient data caps overall score
- All thresholds are tunable - consider A/B testing changes with real user data

### When extending keystroke capture (HumanTypedTextView):
- Override additional `UITextInput` methods if tracking paste events, autocorrect, etc.
- Session state is managed via `sessionStartTime` and `lastKeystrokeTime`
- Call `resetSession()` to clear data between independent typing sessions

### Demo app integration (ContentView.swift):
- Uses `UIViewRepresentable` to bridge UIKit `HumanTypedTextView` into SwiftUI
- Updates metrics on every `textViewDidChange` callback (line 123)
- Real-time scoring recalculates `HumanConfidenceScore` on each keystroke

## Platform Requirements

- iOS framework targeting UIKit (not AppKit/macOS)
- Uses `UITextView`, `CACurrentMediaTime()`, `UIViewRepresentable`
- Demo app requires SwiftUI (iOS 14+)
