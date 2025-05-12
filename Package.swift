// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SwiftFlagCleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "flagcleaner", targets: ["SwiftFlagCleaner"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(name: "SwiftFlagCleaner", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
        .testTarget(name: "FlagCleanerTests", dependencies: ["SwiftFlagCleaner"])
    ]
)
