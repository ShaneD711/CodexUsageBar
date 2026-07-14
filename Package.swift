// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexUsageBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexUsageBar", targets: ["CodexUsageBar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexUsageBar",
            path: "Sources/CodexUsageBar",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "CodexUsageBarTests",
            dependencies: ["CodexUsageBar"],
            path: "Tests/CodexUsageBarTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
