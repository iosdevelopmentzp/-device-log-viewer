// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LogReaderCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LogReaderCore", targets: ["LogReaderCore"])
    ],
    targets: [
        .target(name: "LogReaderCore"),
        .testTarget(
            name: "LogReaderCoreTests",
            dependencies: ["LogReaderCore"]
        )
    ]
)
