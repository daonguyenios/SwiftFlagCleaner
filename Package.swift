// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "FlagCleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "flagcleaner", targets: ["FlagCleaner"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(name: "FlagCleaner", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
        .testTarget(name: "FlagCleanerTests", dependencies: ["FlagCleaner"])
    ]
)