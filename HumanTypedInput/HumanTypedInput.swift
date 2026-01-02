//
//  HumanTypedInput.swift
//  HumanTypedInput
//
//  Created by Anant Jain on 1/2/26.
//

import UIKit

/// Represents a single keystroke event with timing metadata
public struct KeystrokeEvent {
    public let timestamp: TimeInterval
    public let character: String
    public let timeSincePreviousKey: TimeInterval?
    
    public init(timestamp: TimeInterval, character: String, timeSincePreviousKey: TimeInterval?) {
        self.timestamp = timestamp
        self.character = character
        self.timeSincePreviousKey = timeSincePreviousKey
    }
}

/// A text view that captures typing dynamics to verify human input
public class HumanTypedTextView: UITextView {
    
    // MARK: - Public Properties
    
    /// All keystroke events captured during this typing session
    public private(set) var keystrokeEvents: [KeystrokeEvent] = []
    
    /// The timestamp when typing began
    public private(set) var sessionStartTime: TimeInterval?
    
    // MARK: - Private Properties
    
    private var lastKeystrokeTime: TimeInterval?
    
    // MARK: - Initialization
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Basic default styling - customers can override
        font = UIFont.systemFont(ofSize: 16)
        layer.borderColor = UIColor.systemGray4.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 8
        textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
    }
    
    // MARK: - Keystroke Capture
    
    public override func insertText(_ text: String) {
        let now = CACurrentMediaTime()
        
        // Start session on first keystroke
        if sessionStartTime == nil {
            sessionStartTime = now
        }
        
        // Calculate time since last keystroke
        let timeSincePrevious = lastKeystrokeTime.map { now - $0 }
        
        // Record the event
        let event = KeystrokeEvent(
            timestamp: now,
            character: text,
            timeSincePreviousKey: timeSincePrevious
        )
        keystrokeEvents.append(event)
        
        lastKeystrokeTime = now
        
        // Let the text view do its normal thing
        super.insertText(text)
    }
    
    public override func deleteBackward() {
        let now = CACurrentMediaTime()
        
        if sessionStartTime == nil {
            sessionStartTime = now
        }
        
        let timeSincePrevious = lastKeystrokeTime.map { now - $0 }
        
        // Record deletion as a special event
        let event = KeystrokeEvent(
            timestamp: now,
            character: "[DELETE]",
            timeSincePreviousKey: timeSincePrevious
        )
        keystrokeEvents.append(event)
        
        lastKeystrokeTime = now
        
        super.deleteBackward()
    }
    
    // MARK: - Public Methods
    
    /// Resets all captured typing data for a new session
    public func resetSession() {
        keystrokeEvents.removeAll()
        sessionStartTime = nil
        lastKeystrokeTime = nil
    }
    
    /// Returns a summary of typing dynamics for verification
    public func getTypingMetrics() -> TypingMetrics {
        return TypingMetrics(events: keystrokeEvents, sessionStart: sessionStartTime)
    }
}
