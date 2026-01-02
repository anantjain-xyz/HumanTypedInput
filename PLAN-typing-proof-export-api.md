# Typing Proof Export API - Design Plan

## Overview

This document outlines the API contract for exporting typing proof data from the HumanTypedInput SDK. The export provides a JSON blob containing metrics, confidence scores, and raw keystroke events that customers can send to their backend for verification.

---

## Proposed API Contract

### 1. New Public Method on `HumanTypedTextView`

```swift
/// Exports the current typing session as a verifiable proof
/// - Parameter options: Configuration options for the export
/// - Returns: A TypingProof object that can be serialized to JSON
func exportTypingProof(
    options: TypingProofExportOptions = .standard
) -> TypingProof
```

### 2. Export Options

```swift
public struct TypingProofExportOptions: Sendable {
    /// Include raw keystroke events in the export
    public var includeRawEvents: Bool = true

    /// Include content verification (length + hash)
    public var includeContentVerification: Bool = false

    /// Redact characters in keystroke events (replace with "*")
    /// Preserves timing data while hiding actual content
    public var redactCharacters: Bool = false

    /// Preset configurations
    public static let standard = TypingProofExportOptions()
    public static let minimal = TypingProofExportOptions(
        includeRawEvents: false,
        includeContentVerification: false
    )
    public static let redacted = TypingProofExportOptions(
        includeRawEvents: true,
        redactCharacters: true
    )
    public static let full = TypingProofExportOptions(
        includeRawEvents: true,
        includeContentVerification: true,
        redactCharacters: false
    )
}
```

### 3. New `TypingProof` Model (Codable)

```swift
public struct TypingProof: Codable, Sendable {
    /// Schema version for forward compatibility
    public let version: String  // "1.0"

    /// Metadata about the export
    public let metadata: ProofMetadata

    /// Aggregated metrics from the typing session
    public let metrics: ExportedMetrics

    /// Human confidence score with factor breakdown
    public let confidence: ExportedConfidence

    /// Raw keystroke events (optional, controlled by export parameter)
    public let events: [ExportedKeystrokeEvent]?

    /// Content verification (optional)
    public let content: ContentVerification?
}
```

---

## JSON Export Structure

### Standard Export (`.standard`)

```json
{
  "version": "1.0",
  "metadata": {
    "exportedAt": "2026-01-02T14:30:00.000Z",
    "sessionStartedAt": "2026-01-02T14:25:12.345Z",
    "sessionDurationMs": 287655,
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
      {
        "name": "Sample Volume",
        "score": 100,
        "weight": 0.10,
        "explanation": "Sufficient keystrokes (156) for reliable analysis"
      },
      {
        "name": "Timing Variance",
        "score": 95,
        "weight": 0.25,
        "explanation": "Natural human variance detected (CV: 0.39)"
      },
      {
        "name": "Typing Speed",
        "score": 100,
        "weight": 0.20,
        "explanation": "Normal typing speed (~54 WPM)"
      },
      {
        "name": "Correction Rate",
        "score": 85,
        "weight": 0.20,
        "explanation": "Normal correction rate (7.7%)"
      },
      {
        "name": "Burst Pattern",
        "score": 100,
        "weight": 0.25,
        "explanation": "No suspicious rapid keystroke bursts detected"
      }
    ]
  },
  "events": [
    {
      "index": 0,
      "timestampMs": 0,
      "character": "H",
      "intervalMs": null
    },
    {
      "index": 1,
      "timestampMs": 187,
      "character": "e",
      "intervalMs": 187
    },
    {
      "index": 2,
      "timestampMs": 342,
      "character": "l",
      "intervalMs": 155
    }
  ],
  "content": null
}
```

### Minimal Export (`.minimal`)

Lightweight payload with just score and metrics—no raw events or content verification.

```json
{
  "version": "1.0",
  "metadata": {
    "exportedAt": "2026-01-02T14:30:00.000Z",
    "sessionStartedAt": "2026-01-02T14:25:12.345Z",
    "sessionDurationMs": 287655,
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
    "factors": [...]
  },
  "events": null,
  "content": null
}
```

### Redacted Export (`.redacted`)

Full timing data with characters replaced by `"*"` for privacy.

```json
{
  "version": "1.0",
  "metadata": {...},
  "metrics": {...},
  "confidence": {...},
  "events": [
    {
      "index": 0,
      "timestampMs": 0,
      "character": "*",
      "intervalMs": null
    },
    {
      "index": 1,
      "timestampMs": 187,
      "character": "*",
      "intervalMs": 187
    },
    {
      "index": 2,
      "timestampMs": 342,
      "character": "*",
      "intervalMs": 155
    },
    {
      "index": 3,
      "timestampMs": 520,
      "character": "[DELETE]",
      "intervalMs": 178
    }
  ],
  "content": null
}
```

Note: `[DELETE]` is preserved (not redacted) since it doesn't reveal content.

### Full Export (`.full`)

Everything included: raw events with actual characters + content verification.

```json
{
  "version": "1.0",
  "metadata": {...},
  "metrics": {...},
  "confidence": {...},
  "events": [
    {"index": 0, "timestampMs": 0, "character": "H", "intervalMs": null},
    {"index": 1, "timestampMs": 187, "character": "e", "intervalMs": 187},
    ...
  ],
  "content": {
    "length": 142,
    "sha256": "a1b2c3d4e5f6..."
  }
}
```

---

## New Data Models

### `ProofMetadata`
```swift
public struct ProofMetadata: Codable, Sendable {
    /// ISO8601 timestamp when the proof was exported
    public let exportedAt: String

    /// ISO8601 timestamp when the typing session started
    public let sessionStartedAt: String?

    /// Total session duration in milliseconds
    public let sessionDurationMs: Int?

    /// SDK version for compatibility tracking
    public let sdkVersion: String

    /// Platform identifier (e.g., "iOS")
    public let platform: String

    /// Platform OS version
    public let platformVersion: String
}
```

### `ExportedMetrics`
```swift
public struct ExportedMetrics: Codable, Sendable {
    /// Total number of keystrokes captured
    public let totalKeystrokes: Int

    /// Number of deletion/backspace events
    public let deletionCount: Int

    /// Ratio of deletions to total keystrokes (0.0 - 1.0)
    public let correctionRate: Double

    /// Average time between keystrokes in milliseconds
    public let averageIntervalMs: Double?

    /// Standard deviation of keystroke intervals in milliseconds
    public let timingVarianceMs: Double?

    /// Estimated words per minute
    public let estimatedWPM: Int?
}
```

### `ExportedConfidence`
```swift
public struct ExportedConfidence: Codable, Sendable {
    /// Overall confidence score (0-100)
    public let score: Int

    /// Human-readable interpretation
    public let interpretation: String

    /// Breakdown of individual scoring factors
    public let factors: [ExportedScoringFactor]
}

public struct ExportedScoringFactor: Codable, Sendable {
    /// Factor name (e.g., "Timing Variance")
    public let name: String

    /// Factor score (0-100)
    public let score: Int

    /// Factor weight in overall calculation (0.0 - 1.0)
    public let weight: Double

    /// Human-readable explanation
    public let explanation: String
}
```

### `ExportedKeystrokeEvent`
```swift
public struct ExportedKeystrokeEvent: Codable, Sendable {
    /// Sequential index of the keystroke
    public let index: Int

    /// Milliseconds since session start (normalized)
    public let timestampMs: Int

    /// Character typed (or "[DELETE]" for backspace)
    public let character: String

    /// Milliseconds since previous keystroke (null for first)
    public let intervalMs: Int?
}
```

### `ContentVerification` (Optional)
```swift
public struct ContentVerification: Codable, Sendable {
    /// Length of the final text content
    public let length: Int

    /// SHA256 hash of the final text content
    public let sha256: String
}
```

---

## Convenience Methods

### Direct JSON Export
```swift
extension TypingProof {
    /// Exports the proof as a JSON Data blob
    func toJSONData() throws -> Data

    /// Exports the proof as a JSON String
    func toJSONString() throws -> String

    /// Exports the proof as a Dictionary for custom serialization
    func toDictionary() throws -> [String: Any]
}
```

### Shorthand on HumanTypedTextView
```swift
extension HumanTypedTextView {
    /// Exports typing proof directly as JSON Data
    func exportTypingProofAsJSON(
        options: TypingProofExportOptions = .standard
    ) throws -> Data
}
```

### Usage Examples
```swift
// Standard export with raw events
let proof = textView.exportTypingProof()
let json = try proof.toJSONData()

// Minimal export for bandwidth-constrained scenarios
let minimalProof = textView.exportTypingProof(options: .minimal)

// Redacted export for maximum privacy
let redactedProof = textView.exportTypingProof(options: .redacted)

// Full export with content verification
let fullProof = textView.exportTypingProof(options: .full)

// Custom options
var customOptions = TypingProofExportOptions()
customOptions.includeRawEvents = true
customOptions.redactCharacters = true
customOptions.includeContentVerification = true
let customProof = textView.exportTypingProof(options: customOptions)
```

---

## Design Decisions & Rationale

### 1. **Timestamps in Milliseconds (not Seconds)**
- More intuitive for web/backend developers
- Avoids floating-point precision issues in JSON
- Matches JavaScript's native timing conventions

### 2. **Relative Timestamps (from Session Start)**
- Protects user privacy (no absolute wall-clock times in events)
- Smaller payload (integers vs ISO8601 strings)
- Easier to analyze patterns without calendar context
- Metadata contains absolute times for audit trail

### 3. **Optional Raw Events**
- `includeRawEvents: false` produces a lightweight summary
- Useful for bandwidth-constrained mobile scenarios
- Customers can choose privacy vs. verification depth

### 4. **Optional Content Verification**
- `includeTextContent: false` by default for privacy
- Only exports length + hash, not actual text
- Customers can enable if they need to verify content matches

### 5. **Schema Version Field**
- Allows backward-compatible API evolution
- Backend can handle multiple versions during migration
- Semantic versioning (major.minor)

### 6. **Platform Metadata**
- Helps backends understand context (iOS vs future Android)
- SDK version enables debugging/compatibility checks

### 7. **Sendable Conformance**
- All models are `Sendable` for Swift 6 concurrency safety
- Can be safely passed across actor boundaries

---

## Implementation Steps

1. **Create `TypingProof.swift`** - New file with all export models
   - `TypingProofExportOptions` (with `.standard`, `.minimal`, `.redacted`, `.full` presets)
   - `TypingProof`
   - `ProofMetadata`
   - `ExportedMetrics`
   - `ExportedConfidence`
   - `ExportedScoringFactor`
   - `ExportedKeystrokeEvent`
   - `ContentVerification`

2. **Add Codable conformance** - All structs implement `Codable` and `Sendable`

3. **Add JSON export convenience methods** - `toJSONData()`, `toJSONString()`

4. **Extend `HumanTypedTextView`** - Add `exportTypingProof(options:)` method

5. **Add helper for WPM calculation** - Extract from `HumanConfidenceScore`

6. **Implement character redaction logic** - Replace characters with `"*"` when `redactCharacters: true`

7. **Update demo app** - Show export functionality in action

8. **Add DocC documentation** - Document the new API

---

## Future Considerations (Out of Scope for v1.0)

- **Cryptographic Signing**: Sign the proof with a device key or SDK key
- **Server-Side Verification SDK**: Backend library to validate proofs
- **Compression**: gzip for large keystroke arrays
- **Streaming Export**: Export partial proofs during long sessions
- **Proof Chaining**: Link multiple text fields in a form

---

## Resolved Design Questions

1. ~~**Character Redaction**~~ → ✅ Added `.redacted` preset and `redactCharacters` option
2. ~~**Minimum Viable Export**~~ → ✅ Added `.minimal` preset (no events, no content)
3. **Factor Weights in Export** → Include weights for transparency (backend can re-calculate)
4. **Timestamp Precision** → Milliseconds (sufficient for human typing analysis)
5. **Content Hash Algorithm** → SHA256 (industry standard, no need for alternatives)
