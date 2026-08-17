// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PokeBinder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PokeBinder",
            path: "Sources/PokeBinder"
        )
    ]
)
