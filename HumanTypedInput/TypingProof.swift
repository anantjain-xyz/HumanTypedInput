//
//  TypingProof.swift
//  HumanTypedInput
//
//  Created by Anant Jain on 1/2/26.
//

import Foundation
import UIKit

// MARK: - Typing Proof

/// A verifiable proof of typing behavior that can be serialized to JSON
public struct TypingProof: Codable, Sendable {
    /// Schema version for forward compatibility
    public let version: String

    /// Metadata about the export
    public let metadata: ProofMetadata

    /// Aggregated metrics from the typing session
    public let metrics: ExportedMetrics

    /// Human confidence score with factor breakdown
    public let confidence: ExportedConfidence
}

// MARK: - Proof Metadata

/// Metadata about the typing proof export
public struct ProofMetadata: Codable, Sendable {
    /// ISO8601 timestamp when the proof was exported
    public let exportedAt: String

    /// ISO8601 timestamp when the typing session started
    public let sessionStartedAt: String?

    /// Total session duration in milliseconds
    public let sessionDurationMs: Int?

    /// SDK version for compatibility tracking
    public let sdkVersion: String

    /// Platform identifier
    public let platform: String

    /// Platform OS version
    public let platformVersion: String
}

// MARK: - Exported Metrics

/// Aggregated typing metrics for export
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

// MARK: - Exported Confidence

/// Human confidence score with factor breakdown for export
public struct ExportedConfidence: Codable, Sendable {
    /// Overall confidence score (0-100)
    public let score: Int

    /// Human-readable interpretation
    public let interpretation: String

    /// Breakdown of individual scoring factors
    public let factors: [ExportedScoringFactor]
}

/// Individual scoring factor for export
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

// MARK: - JSON Export Extensions

public extension TypingProof {
    /// Exports the proof as JSON Data
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Exports the proof as a JSON String
    func toJSONString() throws -> String {
        let data = try toJSONData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw TypingProofError.encodingFailed
        }
        return string
    }

    /// Exports the proof as a Dictionary
    func toDictionary() throws -> [String: Any] {
        let data = try toJSONData()
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TypingProofError.encodingFailed
        }
        return dictionary
    }
}

/// Errors that can occur during typing proof export
public enum TypingProofError: Error, LocalizedError {
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode typing proof to the requested format"
        }
    }
}

// MARK: - HumanTypedTextView Export Extension

public extension HumanTypedTextView {

    /// SDK version constant
    static let sdkVersion = "1.0.0"

    /// Exports the current typing session as a verifiable proof
    /// - Returns: A TypingProof object that can be serialized to JSON
    func exportTypingProof() -> TypingProof {
        let metrics = getTypingMetrics()
        let confidenceScore = HumanConfidenceScore(metrics: metrics)

        // Build metadata
        let metadata = buildMetadata(metrics: metrics)

        // Build exported metrics
        let exportedMetrics = buildExportedMetrics(metrics: metrics)

        // Build exported confidence
        let exportedConfidence = buildExportedConfidence(score: confidenceScore)

        return TypingProof(
            version: "1.0",
            metadata: metadata,
            metrics: exportedMetrics,
            confidence: exportedConfidence
        )
    }

    /// Exports typing proof directly as JSON Data
    func exportTypingProofAsJSON() throws -> Data {
        return try exportTypingProof().toJSONData()
    }

    // MARK: - Private Helpers

    private func buildMetadata(metrics: TypingMetrics) -> ProofMetadata {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Calculate session start as wall-clock time
        // sessionStartTime is from CACurrentMediaTime, so we need to convert
        let sessionStartedAt: String?
        if let sessionStart = sessionStartTime {
            let currentCATime = CACurrentMediaTime()
            let elapsed = currentCATime - sessionStart
            let sessionStartDate = now.addingTimeInterval(-elapsed)
            sessionStartedAt = formatter.string(from: sessionStartDate)
        } else {
            sessionStartedAt = nil
        }

        let sessionDurationMs: Int?
        if let duration = metrics.sessionDuration {
            sessionDurationMs = Int(duration * 1000)
        } else {
            sessionDurationMs = nil
        }

        return ProofMetadata(
            exportedAt: formatter.string(from: now),
            sessionStartedAt: sessionStartedAt,
            sessionDurationMs: sessionDurationMs,
            sdkVersion: Self.sdkVersion,
            platform: "iOS",
            platformVersion: UIDevice.current.systemVersion
        )
    }

    private func buildExportedMetrics(metrics: TypingMetrics) -> ExportedMetrics {
        let averageIntervalMs: Double?
        if let avg = metrics.averageTimeBetweenKeys {
            averageIntervalMs = avg * 1000
        } else {
            averageIntervalMs = nil
        }

        let timingVarianceMs: Double?
        if let variance = metrics.timingVariance {
            timingVarianceMs = variance * 1000
        } else {
            timingVarianceMs = nil
        }

        let estimatedWPM: Int?
        if let avg = metrics.averageTimeBetweenKeys, avg > 0 {
            let charsPerMinute = 60.0 / avg
            estimatedWPM = Int(charsPerMinute / 5.0)
        } else {
            estimatedWPM = nil
        }

        return ExportedMetrics(
            totalKeystrokes: metrics.totalKeystrokes,
            deletionCount: metrics.deletionCount,
            correctionRate: metrics.correctionRate,
            averageIntervalMs: averageIntervalMs,
            timingVarianceMs: timingVarianceMs,
            estimatedWPM: estimatedWPM
        )
    }

    private func buildExportedConfidence(score: HumanConfidenceScore) -> ExportedConfidence {
        let weights = [0.1, 0.25, 0.2, 0.2, 0.25]

        let exportedFactors = score.factors.enumerated().map { index, factor in
            ExportedScoringFactor(
                name: factor.name,
                score: factor.score,
                weight: index < weights.count ? weights[index] : 0,
                explanation: factor.explanation
            )
        }

        return ExportedConfidence(
            score: score.score,
            interpretation: score.interpretation,
            factors: exportedFactors
        )
    }
}
