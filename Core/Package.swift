// swift-tools-version:5.9
import PackageDescription

// Pure-Swift logic (no UI): settings, state machine, formatting.
// Builds and tests on macOS and Linux.
let package = Package(
    name: "BreakBarCore",
    products: [.library(name: "BreakBarCore", targets: ["BreakBarCore"])],
    targets: [
        .target(name: "BreakBarCore"),
        .testTarget(name: "BreakBarCoreTests", dependencies: ["BreakBarCore"]),
    ]
)
