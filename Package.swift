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
        .testTarget(
            name: "CloudLyricBarCoreTests",
            dependencies: ["CloudLyricBarCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
