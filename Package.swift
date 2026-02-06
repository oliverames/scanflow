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
        .library(
            name: "ScanFlow",
            targets: ["ScanFlow"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "ScanFlow",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS]))
            ],
            path: "ScanFlow",
            exclude: ["ScanFlowApp.swift"],
            resources: [
                .process("Resources/Info-macOS.plist"),
                .process("ScanFlow.entitlements")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .testTarget(
            name: "ScanFlowTests",
            dependencies: ["ScanFlow"],
            path: "Tests"
        )
    ]
)
