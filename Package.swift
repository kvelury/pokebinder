// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PokeBinder",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "PokeBinder",
            path: "Sources/PokeBinder",
            resources: [
                .copy("Resources/TypeIcons")
            ]
        )
    ]
)
