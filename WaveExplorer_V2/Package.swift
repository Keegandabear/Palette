// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WaveExplorer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // The reusable logic — this is what Palette will eventually depend on.
        .library(
            name: "WaveExplorerCore",
            targets: ["WaveExplorerCore"]
        ),
        // The throwaway debug UI. Kept as a separate executable so Core
        // has zero SwiftUI/App-lifecycle baggage.
        .executable(
            name: "WaveExplorerApp",
            targets: ["WaveExplorerApp"]
        )
    ],
    targets: [
        .target(
            name: "WaveExplorerCore",
            dependencies: [],
            path: "Sources/WaveExplorerCore"
            // NOTE: If the Tangent Developer Support Pack ships a static lib /
            // XCFramework instead of being pure sockets, it gets linked here via
            // .linkedLibrary(...) or a binaryTarget. See README "SDK linking" note.
        ),
        .executableTarget(
            name: "WaveExplorerApp",
            dependencies: ["WaveExplorerCore"],
            path: "Sources/WaveExplorerApp"
        ),
        .testTarget(
            name: "WaveExplorerCoreTests",
            dependencies: ["WaveExplorerCore"],
            path: "Tests/WaveExplorerCoreTests"
        )
    ]
)
