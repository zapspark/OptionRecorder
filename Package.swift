// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OptionRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WheelStrategyCore",
            targets: ["WheelStrategyCore"]
        ),
        .executable(
            name: "OptionRecoderApp",
            targets: ["OptionRecoderApp"]
        )
    ],
    targets: [
        .target(
            name: "WheelStrategyCore"
        ),
        .executableTarget(
            name: "OptionRecoderApp",
            dependencies: ["WheelStrategyCore"]
        ),
        .testTarget(
            name: "WheelStrategyCoreTests",
            dependencies: ["WheelStrategyCore"]
        )
    ]
)
