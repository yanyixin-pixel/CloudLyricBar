// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CloudLyricBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CloudLyricBarCore",
            targets: ["CloudLyricBarCore"]
        ),
        .executable(
            name: "CloudLyricBarApp",
            targets: ["CloudLyricBarApp"]
        ),
        .executable(
            name: "CloudLyricBarCoreTests",
            targets: ["CloudLyricBarCoreTests"]
        )
    ],
    targets: [
        .target(
            name: "CloudLyricBarCore"
        ),
        .executableTarget(
            name: "CloudLyricBarApp",
            dependencies: ["CloudLyricBarCore"]
        ),
        .executableTarget(
            name: "CloudLyricBarCoreTests",
            dependencies: ["CloudLyricBarCore"],
            path: "Tests/CloudLyricBarCoreTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
