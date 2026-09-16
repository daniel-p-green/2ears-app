// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwoEars",
    platforms: [.macOS(.v14), .watchOS(.v10), .iOS(.v17)],
    products: [
        .library(name: "TwoEarsCore", targets: ["TwoEarsCore"]),
        .library(name: "TwoEarsLabKit", targets: ["TwoEarsLabKit"]),
        .executable(name: "twoears-lab", targets: ["TwoEarsLab"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    ],
    targets: [
        .target(name: "TwoEarsCore"),
        .target(name: "TwoEarsLabKit", dependencies: ["TwoEarsCore"]),
        .executableTarget(
            name: "TwoEarsLab",
            dependencies: [
                "TwoEarsCore",
                "TwoEarsLabKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "TwoEarsCoreTests", dependencies: ["TwoEarsCore"]),
        .testTarget(name: "TwoEarsLabKitTests", dependencies: ["TwoEarsCore", "TwoEarsLabKit"]),
    ],
    swiftLanguageModes: [.v5]
)
