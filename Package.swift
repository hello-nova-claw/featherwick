// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Featherwick",
    defaultLocalization: "en",
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
        // Its String Catalog is in Resources; Xcode compiles it for the app.
        .target(name: "FeatherwickText", dependencies: ["FeatherwickCore"], resources: [.process("Resources")]),
        // Thin text front end over the core.
        .executableTarget(name: "FeatherwickCLI", dependencies: ["FeatherwickCore", "FeatherwickText"]),
        .testTarget(
            name: "FeatherwickCoreTests", dependencies: ["FeatherwickCore"],
            resources: [.copy("Fixtures")]),  // real saves from older versions
        .testTarget(name: "FeatherwickTextTests", dependencies: ["FeatherwickCore", "FeatherwickText"]),
    ]
)
