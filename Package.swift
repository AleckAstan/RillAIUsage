// swift-tools-version: 6.0
import PackageDescription
import Foundation

let localSDK = ProcessInfo.processInfo.environment["RILL_SDK_PATH"]
let sdk: Package.Dependency = localSDK.map { .package(path: $0) }
    ?? .package(url: "https://github.com/AleckAstan/Rill.git", exact: "0.1.0")
let sdkIdentity = localSDK.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Rill"

let package = Package(
    name: "RillAIUsage",
    platforms: [.macOS(.v14)],
    dependencies: [sdk],
    targets: [
        .executableTarget(name: "RillAIUsage", dependencies: [
            .product(name: "RillExtensionKit", package: sdkIdentity)
        ]),
        .testTarget(name: "RillAIUsageTests", dependencies: ["RillAIUsage"])
    ]
)
