# File Structure

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
