# Architecture

## Core data flow

1. Input capture (HumanTypedTextView in HumanTypedInput.swift)
   - Subclass of UITextView that intercepts insertText(_:) and deleteBackward().
   - Captures each keystroke with high-precision timing using CACurrentMediaTime().
   - Records timestamp, character, and time-since-previous-key for every event.
   - Deletions are tracked as special [DELETE] character events.

2. Metric calculation (TypingMetrics in TypingMetrics.swift)
   - Aggregates raw keystroke events into statistical metrics.
   - Calculates average inter-keystroke interval, standard deviation, session duration.
   - Computes correction rate (ratio of deletions to total keystrokes).
   - All timing uses TimeInterval (seconds as Double).

3. Human confidence scoring (HumanConfidenceScore in HumanConfidenceScore.swift)
   - Multi-factor analysis producing a 0-100 confidence score.
   - Scoring factors:
     - Sample volume: requires 30+ keystrokes for high confidence.
     - Timing variance: humans are inconsistent (coefficient of variation 0.3-0.8 is ideal).
     - Typing speed: 30-80 WPM is normal; >200 WPM is suspiciously fast.
     - Correction rate: 5-20% deletions is typical; 0% is suspicious.
     - Burst detection: intervals <20ms are near-impossible for humans.
   - Uses weighted average: [0.1, 0.25, 0.2, 0.2, 0.25] for each factor.

## Key design decisions

- High-precision timing: uses CACurrentMediaTime() instead of Date() for monotonic, sub-millisecond accuracy.
- Statistical thresholds: ranges (WPM, variance, etc.) are heuristic-based and may need tuning with real-world data.
- Progressive confidence: low keystroke counts result in capped scores, even if patterns look human.
- Deletion tracking: captures backspace events since humans naturally make corrections.
