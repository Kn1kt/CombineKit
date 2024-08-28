// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "CombineKit",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "CombineKit", targets: ["CombineKit"]),
    ],
    targets: [
        .target(
            name: "CombineKit"
        ),
        .testTarget(
            name: "CombineKitTests",
            dependencies: ["CombineKit"]
        ),
    ]
)
