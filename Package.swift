// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocGenerator",
    platforms: [.macOS(.v11)],
    products: [
        .executable(
            name: "DocGenerator",
            targets: ["DocGenerator"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.1.1")),
        .package(url: "https://github.com/mediamonks/MMMCommonCore", .upToNextMajor(from: "1.8.4"))
    ],
    targets: [
        .executableTarget(
            name: "DocGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MMMCommonCore", package: "MMMCommonCore")
            ]
        ),
        .testTarget(
            name: "DocGeneratorTests",
            dependencies: ["DocGenerator"]
        )
    ]
)
