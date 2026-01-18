# Development Notes

## When modifying the scoring algorithm (HumanConfidenceScore.swift)

- Each scoring function returns a ScoringFactor with score (0-100) and explanation.
- Weights in line 67 must sum to 1.0.
- Volume score acts as a gating factor (line 63-66): insufficient data caps the overall score.
- All thresholds are tunable; consider A/B testing changes with real user data.

## When extending keystroke capture (HumanTypedTextView)

- Override additional UITextInput methods if tracking paste events, autocorrect, etc.
- Session state is managed via sessionStartTime and lastKeystrokeTime.
- Call resetSession() to clear data between independent typing sessions.

## Demo app integration (ContentView.swift)

- Uses UIViewRepresentable to bridge UIKit HumanTypedTextView into SwiftUI.
- Updates metrics on every textViewDidChange callback.
- Real-time scoring recalculates HumanConfidenceScore on each keystroke.
