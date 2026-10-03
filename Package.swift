// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Featherwick",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FeatherwickCore", targets: ["FeatherwickCore"]),
        .executable(name: "featherwick", targets: ["FeatherwickCLI"]),
    ],
    targets: [
        // Pure game logic. No printing, no input, no system clock, no global random.
        .target(name: "FeatherwickCore"),
        // Thin text front end over the core.
        .executableTarget(name: "FeatherwickCLI", dependencies: ["FeatherwickCore"]),
        .testTarget(name: "FeatherwickCoreTests", dependencies: ["FeatherwickCore"]),
    ]
)
