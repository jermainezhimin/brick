// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Brick",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Brick",
            targets: ["Brick"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Brick",
            path: "Sources/Brick"
        )
    ]
)
