// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Rill",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Rill", path: "Sources/Rill"),
    ]
)
