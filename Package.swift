// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Rill",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Rill",
            dependencies: ["CRemux"],
            path: "Sources/Rill"
        ),
        // Stream-copies MKV/AVI/FLV into MP4 through the bundled FFmpeg
        // libraries (see Scripts/fetch-ffmpeg.sh). Unsafe flags are fine here:
        // Rill is an application, never a package dependency.
        .target(
            name: "CRemux",
            path: "Sources/CRemux",
            cSettings: [.unsafeFlags(["-I", "Vendor/ffmpeg/include"])],
            linkerSettings: [
                .unsafeFlags(["-L", "Vendor/ffmpeg/lib"]),
                .linkedLibrary("avformat"),
                .linkedLibrary("avcodec"),
                .linkedLibrary("avutil"),
            ]
        ),
        .testTarget(name: "RillTests", dependencies: ["Rill"], path: "Tests/RillTests"),
    ]
)
