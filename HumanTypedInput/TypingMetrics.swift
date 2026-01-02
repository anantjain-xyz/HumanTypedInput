//
//  TypingMetrics.swift
//  HumanTypedInput
//
//  Created by Anant Jain on 1/2/26.
//


import Foundation

/// Analyzed metrics from a typing session
public struct TypingMetrics {

    /// Total number of keystrokes (including deletions)
    public let totalKeystrokes: Int

    /// Number of deletions/corrections
    public let deletionCount: Int

    /// Average time between keystrokes in seconds
    public let averageTimeBetweenKeys: TimeInterval?

    /// Standard deviation of time between keystrokes
    public let timingVariance: Double?

    /// Total duration of typing session
    public let sessionDuration: TimeInterval?

    /// Ratio of deletions to total keystrokes (higher might indicate human editing)
    public let correctionRate: Double

    /// Raw keystroke events for detailed analysis
    public let events: [KeystrokeEvent]

    /// Number of explicit paste operations detected
    public let pasteCount: Int

    /// Total characters inserted via paste
    public let pastedCharacterCount: Int

    /// Raw paste events for detailed analysis
    public let pasteEvents: [PasteEvent]

    public init(events: [KeystrokeEvent], pasteEvents: [PasteEvent] = [], sessionStart: TimeInterval?) {
        self.events = events
        self.pasteEvents = pasteEvents
        self.totalKeystrokes = events.count
        self.deletionCount = events.filter { $0.character == "[DELETE]" }.count
        self.correctionRate = events.isEmpty ? 0 : Double(deletionCount) / Double(events.count)

        // Calculate paste metrics
        self.pasteCount = pasteEvents.count
        self.pastedCharacterCount = pasteEvents.reduce(0) { $0 + $1.characterCount }

        // Calculate session duration
        if let start = sessionStart, let lastEvent = events.last {
            self.sessionDuration = lastEvent.timestamp - start
        } else {
            self.sessionDuration = nil
        }
        
        // Calculate timing statistics
        let intervals = events.compactMap { $0.timeSincePreviousKey }
        
        if intervals.isEmpty {
            self.averageTimeBetweenKeys = nil
            self.timingVariance = nil
        } else {
            let average = intervals.reduce(0, +) / Double(intervals.count)
            self.averageTimeBetweenKeys = average
            
            // Standard deviation
            let squaredDiffs = intervals.map { pow($0 - average, 2) }
            let variance = squaredDiffs.reduce(0, +) / Double(intervals.count)
            self.timingVariance = sqrt(variance)
        }
    }
}