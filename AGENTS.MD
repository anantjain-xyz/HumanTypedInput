# AGENTS

HumanTypedInput is an iOS Swift framework that detects human-typed vs pasted/automated input using keystroke timing, with a SwiftUI demo app.

Package manager: none (Xcode project).

## Build commands

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

## More details

- [Project overview](docs/agents/project-overview.md)
- [Architecture](docs/agents/architecture.md)
- [Development notes](docs/agents/development-notes.md)
- [File structure](docs/agents/file-structure.md)
- [Platform requirements](docs/agents/platform.md)
- [Build notes](docs/agents/build.md)
