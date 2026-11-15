// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LogReaderKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LogReaderKit", targets: ["LogReaderKit"])
    ],
    dependencies: [
        .package(path: "../LogReaderCore")
    ],
    targets: [
        .target(
            name: "LogReaderKit",
            dependencies: [
                .product(name: "LogReaderCore", package: "LogReaderCore")
            ]
        ),
        .testTarget(
            name: "LogReaderKitTests",
            dependencies: [
                "LogReaderKit",
                .product(name: "LogReaderCore", package: "LogReaderCore")
            ]
        )
    ]
)
