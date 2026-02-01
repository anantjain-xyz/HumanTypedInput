# Contributing

Thanks for helping improve HumanTypedInput.

## Before you start

- Please search existing issues and PRs before opening new ones.
- For security issues, **do not** open a public issue. See `SECURITY.md`.

## Development setup

This project is an Xcode project (no package manager).

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

## Pull requests

- Keep PRs focused and small when possible.
- Include a clear description of the behavior change and why it is needed.
- Add or update tests/examples when relevant.
- Make sure the demo app still builds.

## Coding guidelines

- Prefer clear, explicit naming over brevity.
- Avoid introducing external dependencies unless discussed in an issue.
- Keep public API additions well-documented.

## Versioning

We follow semantic versioning for public API changes.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
