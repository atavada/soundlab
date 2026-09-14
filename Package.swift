// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundLab",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "SoundLabCore", targets: ["SoundLabCore"]),
        .library(name: "SoundLabUI", targets: ["SoundLabUI"]),
        .executable(name: "SoundLabApp", targets: ["SoundLabApp"])
    ],
    targets: [
        .target(
            name: "SoundLabCore",
            dependencies: [],
            path: "Sources/SoundLabCore"
        ),
        .target(
            name: "SoundLabUI",
            dependencies: ["SoundLabCore"],
            path: "Sources/SoundLabUI"
        ),
        .executableTarget(
            name: "SoundLabApp",
            dependencies: ["SoundLabCore", "SoundLabUI"],
            path: "Sources/SoundLabApp"
        ),
        .testTarget(
            name: "SoundLabCoreTests",
            dependencies: ["SoundLabCore"],
            path: "Tests/SoundLabCoreTests"
        )
    ]
)
