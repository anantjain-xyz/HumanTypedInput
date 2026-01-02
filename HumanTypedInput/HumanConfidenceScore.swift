//
//  HumanConfidenceScore.swift
//  HumanTypedInput
//
//  Created by Anant Jain on 1/2/26.
//


import Foundation

/// A confidence assessment of whether input was typed by a human
public struct HumanConfidenceScore {
    
    /// Overall confidence score from 0-100
    public let score: Int
    
    /// Individual factor scores and explanations
    public let factors: [ScoringFactor]
    
    /// Simple interpretation of the score
    public var interpretation: String {
        switch score {
        case 80...100: return "High confidence: likely human typed"
        case 50...79: return "Medium confidence: possibly human typed"
        case 20...49: return "Low confidence: suspicious pattern"
        default: return "Very low confidence: likely pasted or automated"
        }
    }
    
    public struct ScoringFactor {
        public let name: String
        public let score: Int  // 0-100
        public let explanation: String
    }
    
    /// Analyzes typing metrics and produces a confidence score
    public init(metrics: TypingMetrics) {
        var factors: [ScoringFactor] = []
        
        // Factor 1: Did they type enough to analyze?
        let volumeScore = Self.scoreVolume(metrics: metrics)
        factors.append(volumeScore)
        
        // Factor 2: Timing variance (humans are inconsistent)
        let varianceScore = Self.scoreTimingVariance(metrics: metrics)
        factors.append(varianceScore)
        
        // Factor 3: Realistic typing speed
        let speedScore = Self.scoreTypingSpeed(metrics: metrics)
        factors.append(speedScore)
        
        // Factor 4: Presence of corrections (humans make mistakes)
        let correctionScore = Self.scoreCorrectionRate(metrics: metrics)
        factors.append(correctionScore)
        
        // Factor 5: No suspiciously instant bursts
        let burstScore = Self.scoreBurstPatterns(metrics: metrics)
        factors.append(burstScore)

        // Factor 6: Explicit paste detection
        let pasteScore = Self.scorePasteDetection(metrics: metrics)
        factors.append(pasteScore)

        self.factors = factors

        // Weighted average - volume is gating, paste detection is critical
        if volumeScore.score < 30 {
            // Not enough data to judge
            self.score = min(volumeScore.score, 25)
        } else if pasteScore.score == 0 {
            // Paste detected - cap the score severely
            let weights = [0.1, 0.2, 0.15, 0.15, 0.2, 0.2]  // Must sum to 1.0
            let weightedSum = zip(factors, weights).reduce(0.0) { sum, pair in
                sum + Double(pair.0.score) * pair.1
            }
            self.score = min(Int(weightedSum.rounded()), 20)
        } else {
            let weights = [0.1, 0.2, 0.15, 0.15, 0.2, 0.2]  // Must sum to 1.0
            let weightedSum = zip(factors, weights).reduce(0.0) { sum, pair in
                sum + Double(pair.0.score) * pair.1
            }
            self.score = Int(weightedSum.rounded())
        }
    }
    
    // MARK: - Scoring Functions
    
    private static func scoreVolume(metrics: TypingMetrics) -> ScoringFactor {
        let count = metrics.totalKeystrokes
        
        let score: Int
        let explanation: String
        
        switch count {
        case 0:
            score = 0
            explanation = "No keystrokes recorded"
        case 1...5:
            score = 20
            explanation = "Too few keystrokes to analyze reliably"
        case 6...15:
            score = 50
            explanation = "Minimal data, low confidence analysis"
        case 16...30:
            score = 75
            explanation = "Adequate sample size"
        default:
            score = 100
            explanation = "Good sample size for analysis"
        }
        
        return ScoringFactor(name: "Sample Volume", score: score, explanation: explanation)
    }
    
    private static func scoreTimingVariance(metrics: TypingMetrics) -> ScoringFactor {
        guard let variance = metrics.timingVariance, let avg = metrics.averageTimeBetweenKeys else {
            return ScoringFactor(
                name: "Timing Variance",
                score: 0,
                explanation: "No timing data available"
            )
        }
        
        // Coefficient of variation (normalized variance)
        let cv = variance / avg
        
        let score: Int
        let explanation: String
        
        switch cv {
        case 0..<0.1:
            score = 15
            explanation = "Suspiciously consistent timing (robotic)"
        case 0.1..<0.3:
            score = 60
            explanation = "Low variance, possibly automated"
        case 0.3..<0.8:
            score = 100
            explanation = "Natural human timing variance"
        case 0.8..<1.5:
            score = 75
            explanation = "High variance, possibly distracted typing"
        default:
            score = 40
            explanation = "Erratic timing, unusual pattern"
        }
        
        return ScoringFactor(name: "Timing Variance", score: score, explanation: explanation)
    }
    
    private static func scoreTypingSpeed(metrics: TypingMetrics) -> ScoringFactor {
        guard let avg = metrics.averageTimeBetweenKeys, avg > 0 else {
            return ScoringFactor(
                name: "Typing Speed",
                score: 0,
                explanation: "No timing data available"
            )
        }
        
        // Convert to characters per minute
        let charsPerMinute = 60.0 / avg
        // Rough conversion to WPM (average 5 chars per word)
        let estimatedWPM = charsPerMinute / 5.0
        
        let score: Int
        let explanation: String
        
        switch estimatedWPM {
        case 0..<10:
            score = 50
            explanation = "Very slow typing (\(Int(estimatedWPM)) WPM)"
        case 10..<30:
            score = 80
            explanation = "Slow but natural typing (\(Int(estimatedWPM)) WPM)"
        case 30..<80:
            score = 100
            explanation = "Normal typing speed (\(Int(estimatedWPM)) WPM)"
        case 80..<120:
            score = 75
            explanation = "Fast typing (\(Int(estimatedWPM)) WPM)"
        case 120..<200:
            score = 40
            explanation = "Unusually fast (\(Int(estimatedWPM)) WPM)"
        default:
            score = 10
            explanation = "Impossibly fast, likely pasted (\(Int(estimatedWPM)) WPM)"
        }
        
        return ScoringFactor(name: "Typing Speed", score: score, explanation: explanation)
    }
    
    private static func scoreCorrectionRate(metrics: TypingMetrics) -> ScoringFactor {
        let rate = metrics.correctionRate
        
        let score: Int
        let explanation: String
        
        switch rate {
        case 0:
            score = 40
            explanation = "No corrections (unusual for natural typing)"
        case 0.001..<0.05:
            score = 80
            explanation = "Few corrections (careful typist)"
        case 0.05..<0.2:
            score = 100
            explanation = "Normal correction rate (human-like)"
        case 0.2..<0.4:
            score = 70
            explanation = "High correction rate (sloppy or editing)"
        default:
            score = 30
            explanation = "Excessive corrections (unusual pattern)"
        }
        
        return ScoringFactor(name: "Correction Rate", score: score, explanation: explanation)
    }
    
    private static func scoreBurstPatterns(metrics: TypingMetrics) -> ScoringFactor {
        let intervals = metrics.events.compactMap { $0.timeSincePreviousKey }
        
        guard intervals.count >= 5 else {
            return ScoringFactor(
                name: "Burst Detection",
                score: 50,
                explanation: "Not enough data to analyze bursts"
            )
        }
        
        // Count suspiciously fast intervals (< 20ms is near-impossible for humans)
        let suspiciousCount = intervals.filter { $0 < 0.02 }.count
        let suspiciousRatio = Double(suspiciousCount) / Double(intervals.count)
        
        let score: Int
        let explanation: String
        
        switch suspiciousRatio {
        case 0:
            score = 100
            explanation = "No suspicious rapid keystrokes"
        case 0.001..<0.05:
            score = 70
            explanation = "Few rapid keystrokes (possibly key repeat)"
        case 0.05..<0.2:
            score = 40
            explanation = "Multiple rapid bursts detected"
        default:
            score = 10
            explanation = "Frequent impossible speeds (likely pasted)"
        }
        
        return ScoringFactor(name: "Burst Detection", score: score, explanation: explanation)
    }

    private static func scorePasteDetection(metrics: TypingMetrics) -> ScoringFactor {
        let pasteCount = metrics.pasteCount
        let pastedChars = metrics.pastedCharacterCount

        let score: Int
        let explanation: String

        if pasteCount == 0 {
            score = 100
            explanation = "No paste operations detected"
        } else if pasteCount == 1 && pastedChars < 10 {
            score = 60
            explanation = "Minor paste detected (\(pastedChars) chars)"
        } else if pasteCount == 1 {
            score = 20
            explanation = "Paste detected (\(pastedChars) chars)"
        } else {
            score = 0
            explanation = "Multiple pastes detected (\(pasteCount) times, \(pastedChars) total chars)"
        }

        return ScoringFactor(name: "Paste Detection", score: score, explanation: explanation)
    }
}
