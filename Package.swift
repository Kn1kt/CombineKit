// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "combine-extensions",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "CombineExtensions", targets: ["CombineExtensions"]),
    ],
    targets: [
        .target(
            name: "CombineExtensions"
        ),
        .testTarget(
            name: "CombineExtensionsTests",
            dependencies: ["CombineExtensions"]
        ),
    ]
)
