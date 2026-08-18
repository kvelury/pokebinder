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
        .target(
            name: "PokeBinderMatchup",
            path: "Sources/PokeBinderMatchup"
        ),
        .executableTarget(
            name: "PokeBinder",
            dependencies: ["PokeBinderSync", "PokeBinderMatchup"],
            path: "Sources/PokeBinder",
            resources: [
                .copy("Resources/TypeIcons")
            ]
        ),
        // Command Line Tools has no XCTest. These executables are the test suites:
        // `swift run PokeBinderSyncCheck` and `swift run PokeBinderTests`
        .executableTarget(
            name: "PokeBinderSyncCheck",
            dependencies: ["PokeBinderSync"],
            path: "Tests/PokeBinderSyncCheck"
        ),
        .executableTarget(
            name: "PokeBinderTests",
            dependencies: ["PokeBinderMatchup"],
            path: "Tests/PokeBinderTests"
        )
    ]
)
