// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PokeBinder",
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "PokeBinderSync",
            path: "Sources/PokeBinderSync"
        ),
        .executableTarget(
            name: "PokeBinder",
            dependencies: ["PokeBinderSync"],
            path: "Sources/PokeBinder",
            resources: [
                .copy("Resources/TypeIcons")
            ]
        ),
        // Command Line Tools has no XCTest. This executable is the test suite:
        // `swift run PokeBinderSyncCheck`
        .executableTarget(
            name: "PokeBinderSyncCheck",
            dependencies: ["PokeBinderSync"],
            path: "Tests/PokeBinderSyncCheck"
        )
    ]
)
