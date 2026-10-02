// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RillAIUsage",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../Rill/Packages/RillExtensionKit")],
    targets: [
        .executableTarget(name: "RillAIUsage", dependencies: [
            .product(name: "RillExtensionKit", package: "RillExtensionKit")
        ]),
        .testTarget(name: "RillAIUsageTests", dependencies: ["RillAIUsage"])
    ]
)
