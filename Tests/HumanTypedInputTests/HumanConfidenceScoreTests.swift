import XCTest
@testable import HumanTypedInput

/// Parity fixtures for HumanConfidenceScore.
///
/// These fixtures are the contract between the Swift scoring implementation and
/// any downstream port (e.g. the TypeScript port that lives in the Slopper
/// `submit_post` Edge Function). Each fixture pins (a) the inputs needed to
/// reconstruct a TypingMetrics and (b) the expected final score. If you change
/// the scoring weights or any factor's bucket boundaries in
/// HumanConfidenceScore.swift, every downstream port MUST update to match.
final class HumanConfidenceScoreTests: XCTestCase {

    // MARK: Fixture builder

    /// Build a TypingMetrics from synthetic inputs. Mirrors how
    /// HumanTypedTextView would populate the metrics from real keystrokes.
    private func makeMetrics(
        eventCount: Int,
        intervals: [TimeInterval],
        deleteIndices: Set<Int> = [],
        pasteEvents: [(timestamp: TimeInterval, chars: Int)] = []
    ) -> TypingMetrics {
        precondition(eventCount == 0 || intervals.count == eventCount - 1,
                     "Need exactly eventCount-1 intervals (got \(intervals.count) for \(eventCount) events)")

        var events: [KeystrokeEvent] = []
        var t: TimeInterval = 0
        for i in 0..<eventCount {
            let interval: TimeInterval?
            if i == 0 {
                interval = nil
            } else {
                interval = intervals[i - 1]
                t += intervals[i - 1]
            }
            let char = deleteIndices.contains(i) ? "[DELETE]" : "a"
            events.append(KeystrokeEvent(
                timestamp: t,
                character: char,
                timeSincePreviousKey: interval
            ))
        }
        let pastes = pasteEvents.map {
            PasteEvent(timestamp: $0.timestamp, characterCount: $0.chars)
        }
        return TypingMetrics(events: events, pasteEvents: pastes, sessionStart: 0)
    }

    // MARK: Fixtures
    //
    // Each test pins one fixture's expected score. Naming: fixture_<NN>_<label>.
    // Hand-traced expected values are documented inline.

    /// F01 — empty session: zero keystrokes.
    /// volume=0 → score 0; gating cap → final 0.
    func test_fixture_01_empty() {
        let m = makeMetrics(eventCount: 0, intervals: [])
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 0)
    }

    /// F02 — too few keystrokes (3 events at 100ms).
    /// volume=20 (1...5 bucket), gating cap → final 20.
    func test_fixture_02_tooFew() {
        let m = makeMetrics(eventCount: 3, intervals: [0.1, 0.1])
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 20)
    }

    /// F03 — typed 20 chars uniformly + 1 paste of 30 chars.
    /// Paste factor = 20 (single big paste). No gating cap (volume=75, paste≠0).
    /// IEEE 754 detail: 19 × 0.1 sums to 1.9000000000000006, so avg ≈ 0.10000000000000003.
    /// That makes WPM ≈ 119.999..., landing in the [80,120) "Fast" bucket → 75
    /// (NOT the [120,200) "Unusually fast" bucket → 40). Same drift in F09's speed factor.
    /// weighted: 75·0.10 + 15·0.20 + 75·0.15 + 40·0.15 + 100·0.20 + 20·0.20 = 51.75
    func test_fixture_03_typedPlusBigPaste() {
        let m = makeMetrics(
            eventCount: 20,
            intervals: Array(repeating: 0.1, count: 19),
            pasteEvents: [(timestamp: 2.0, chars: 30)]
        )
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 52)
    }

    /// F04 — robotic uniform: 50 events all at 100ms.
    /// CV=0 → variance score 15; WPM=120 → speed score 40.
    /// weighted: 100·0.10 + 15·0.20 + 40·0.15 + 40·0.15 + 100·0.20 + 100·0.20 = 65
    func test_fixture_04_roboticUniform() {
        let m = makeMetrics(
            eventCount: 50,
            intervals: Array(repeating: 0.1, count: 49)
        )
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 65)
    }

    /// F05 — natural variance: 31 events with cycling intervals.
    /// CV ≈ 0.40 (variance score 100), WPM ≈ 77 (speed score 100).
    /// No deletions → corrections score 40. No paste. No bursts.
    /// weighted: 100·0.10 + 100·0.20 + 100·0.15 + 40·0.15 + 100·0.20 + 100·0.20 = 91
    func test_fixture_05_naturalVariance() {
        let cycle: [TimeInterval] = [0.10, 0.15, 0.20, 0.08, 0.25]
        let intervals = (0..<6).flatMap { _ in cycle }   // 30 intervals → 31 events
        let m = makeMetrics(eventCount: 31, intervals: intervals)
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 91)
    }

    /// F06 — impossibly fast: 50 events at 5ms.
    /// WPM=2400 → speed 10; bursts ratio 1.0 → bursts 10; CV=0 → variance 15.
    /// weighted: 100·0.10 + 15·0.20 + 10·0.15 + 40·0.15 + 10·0.20 + 100·0.20 = 42.5
    func test_fixture_06_impossiblyFast() {
        let m = makeMetrics(
            eventCount: 50,
            intervals: Array(repeating: 0.005, count: 49)
        )
        let s = HumanConfidenceScore(metrics: m).score
        // 42.5 rounds to 42 (banker's) or 43 (away-from-zero) depending on platform.
        XCTAssertTrue(s == 42 || s == 43, "Expected 42 or 43 (42.5 rounded), got \(s)")
    }

    /// F07 — slow careful typist: 50 events at 300ms.
    /// CV=0 → variance 15. WPM=40 → speed 100.
    /// weighted: 100·0.10 + 15·0.20 + 100·0.15 + 40·0.15 + 100·0.20 + 100·0.20 = 74
    func test_fixture_07_slowCareful() {
        let m = makeMetrics(
            eventCount: 50,
            intervals: Array(repeating: 0.3, count: 49)
        )
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 74)
    }

    /// F08 — heavy editor: 31 events at 150ms with 9 deletes (correctionRate ≈ 0.29).
    /// Volume=100, variance=15 (CV=0), speed=75 (WPM=80), corrections=70 (0.2..<0.4).
    /// weighted: 100·0.10 + 15·0.20 + 75·0.15 + 70·0.15 + 100·0.20 + 100·0.20 = 74.75 → 75
    func test_fixture_08_heavyEditor() {
        let deletes: Set<Int> = [3, 6, 9, 12, 15, 18, 21, 24, 27]
        let m = makeMetrics(
            eventCount: 31,
            intervals: Array(repeating: 0.15, count: 30),
            deleteIndices: deletes
        )
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 75)
    }

    /// F09 — multiple pastes: 30 events at 150ms + 2 pastes of 20 chars each.
    /// Paste score=0 (multiple pastes) → cap final at min(weighted, 20) = 20.
    func test_fixture_09_multiplePastes() {
        let m = makeMetrics(
            eventCount: 30,
            intervals: Array(repeating: 0.15, count: 29),
            pasteEvents: [(timestamp: 1.0, chars: 20), (timestamp: 2.0, chars: 20)]
        )
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 20)
    }

    /// F10 — ideal human: 51 events with varied timing + 5 deletes.
    /// All factors at 100. Final = 100.
    func test_fixture_10_idealHuman() {
        let cycle: [TimeInterval] = [0.10, 0.15, 0.20, 0.08, 0.25]
        let intervals = (0..<10).flatMap { _ in cycle }  // 50 intervals → 51 events
        let deletes: Set<Int> = [10, 20, 30, 40, 50]
        let m = makeMetrics(
            eventCount: 51,
            intervals: intervals,
            deleteIndices: deletes
        )
        XCTAssertEqual(HumanConfidenceScore(metrics: m).score, 100)
    }

    // MARK: Sanity tests on the exported proof shape

    /// The exported proof carries the canonical 6-factor weight vector.
    /// Regression guard for the bug where TypingProof.swift exported a stale
    /// 5-element weight array. Drives the real `buildExportedConfidence` so
    /// drift in that helper (not just in HumanConfidenceScore) is caught.
    func test_exportedProof_hasSixFactorsWithCanonicalWeights() {
        let m = makeMetrics(
            eventCount: 50,
            intervals: Array(repeating: 0.15, count: 49)
        )
        let score = HumanConfidenceScore(metrics: m)
        let view = HumanTypedTextView(frame: .zero, textContainer: nil)
        let exported = view.buildExportedConfidence(score: score)

        XCTAssertEqual(exported.factors.count, 6, "Exported proof must carry exactly 6 factors")
        XCTAssertEqual(exported.factors.map(\.name), [
            "Sample Volume",
            "Timing Variance",
            "Typing Speed",
            "Correction Rate",
            "Burst Detection",
            "Paste Detection",
        ])
        XCTAssertEqual(
            exported.factors.map(\.weight),
            [0.10, 0.20, 0.15, 0.15, 0.20, 0.20],
            "Exported weights must match the canonical vector used by HumanConfidenceScore"
        )
        XCTAssertEqual(
            exported.factors.map(\.weight).reduce(0, +),
            1.0,
            accuracy: 1e-9,
            "Canonical weights must sum to 1.0"
        )
    }

    /// suspiciousBurstRatio is required for server-side parity — verify the
    /// exported value (not a re-derivation) so drift in the export-specific
    /// `<20ms` threshold or `>=5` interval guard is caught.
    func test_burstRatio_populatedWhenEnoughIntervals() {
        // 10 events: 5 fast (3ms), 4 normal (150ms) → 9 intervals, 5 < 20ms.
        let intervals: [TimeInterval] = [0.003, 0.003, 0.003, 0.003, 0.003, 0.15, 0.15, 0.15, 0.15]
        let m = makeMetrics(eventCount: 10, intervals: intervals)
        let view = HumanTypedTextView(frame: .zero, textContainer: nil)

        let exported = view.buildExportedMetrics(metrics: m)
        XCTAssertEqual(exported.suspiciousBurstRatio ?? -1, 5.0 / 9.0, accuracy: 1e-9)
    }

    /// Below the `>=5` interval guard, suspiciousBurstRatio must be nil so
    /// downstream verifiers can skip the burst factor instead of acting on
    /// a noisy ratio computed from too few samples.
    func test_burstRatio_nilWhenTooFewIntervals() {
        // 4 events → 3 intervals, all suspicious — but below the guard.
        let m = makeMetrics(
            eventCount: 4,
            intervals: [0.003, 0.003, 0.003]
        )
        let view = HumanTypedTextView(frame: .zero, textContainer: nil)

        let exported = view.buildExportedMetrics(metrics: m)
        XCTAssertNil(exported.suspiciousBurstRatio)
    }
}
