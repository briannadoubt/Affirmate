// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AffirmateShared",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26),
        .macCatalyst(.v26),
    ],
    products: [
        .library(
            name: "AffirmateShared",
            targets: ["AffirmateShared"]
        ),
    ],
    targets: [
        .target(name: "AffirmateShared"),
        .testTarget(
            name: "AffirmateSharedTests",
            dependencies: ["AffirmateShared"]
        ),
    ]
)
