// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "AffirmateServer",
    platforms: [.macOS(.v12), .iOS(.v16), .tvOS(.v16)],
    products: [
        .library(name: "AffirmateServer", targets: ["AffirmateServer"]),
    ],
    dependencies: [
        .package(path: "../AffirmateShared"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/apns.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "AffirmateServer",
            dependencies: [
                .product(name: "AffirmateShared", package: "AffirmateShared"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "APNS", package: "apns"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Redis", package: "redis"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "AffirmateServer")]),
        .testTarget(name: "AffirmateServerTests", dependencies: [
            .target(name: "Run"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
