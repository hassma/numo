// swift-tools-version: 6.0
import PackageDescription

// Foundation-only logic for numo: link detection, filtering, reminder planning,
// the reminder ledger and the scheduling engine. No AppKit/EventKit/SwiftUI here,
// so everything can be tested with `swift test` and a manual clock.
let package = Package(
    name: "NumoCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NumoCore", targets: ["NumoCore"])
    ],
    targets: [
        .target(name: "NumoCore"),
        .testTarget(name: "NumoCoreTests", dependencies: ["NumoCore"])
    ]
)
