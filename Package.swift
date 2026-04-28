// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HumanTypedInput",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "HumanTypedInput", targets: ["HumanTypedInput"])
    ],
    targets: [
        .target(
            name: "HumanTypedInput",
            path: "HumanTypedInput"
        ),
        .testTarget(
            name: "HumanTypedInputTests",
            dependencies: ["HumanTypedInput"],
            path: "Tests/HumanTypedInputTests"
        )
    ]
)
