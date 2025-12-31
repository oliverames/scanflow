// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScanFlow",
    platforms: [
        .macOS(.v14),  // macOS 14+ (Sonoma) for better compatibility
        .iOS(.v17)  // iOS 17+
    ],
    products: [
        .executable(
            name: "ScanFlow",
            targets: ["ScanFlow"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ScanFlow",
            dependencies: [],
            path: "PhotoFlow",  // Keep directory name for now
            exclude: [],
            resources: [
                .process("Resources/Info-macOS.plist"),
                .process("PhotoFlow.entitlements")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
