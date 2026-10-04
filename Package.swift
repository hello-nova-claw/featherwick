// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Featherwick",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FeatherwickCore", targets: ["FeatherwickCore"]),
        .library(name: "FeatherwickText", targets: ["FeatherwickText"]),
        .executable(name: "featherwick", targets: ["FeatherwickCLI"]),
    ],
    targets: [
        // Pure game logic. No printing, no input, no system clock, no global random.
        .target(name: "FeatherwickCore"),
        // The words players read, shared by every front end (CLI and app).
        .target(name: "FeatherwickText", dependencies: ["FeatherwickCore"]),
        // Thin text front end over the core.
        .executableTarget(name: "FeatherwickCLI", dependencies: ["FeatherwickCore", "FeatherwickText"]),
        .testTarget(
            name: "FeatherwickCoreTests", dependencies: ["FeatherwickCore"],
            resources: [.copy("Fixtures")]),  // real saves from older versions
        .testTarget(name: "FeatherwickTextTests", dependencies: ["FeatherwickCore", "FeatherwickText"]),
    ]
)
