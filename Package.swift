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
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            .upToNextMinor(from: "600.0.1")
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(from: "1.2.0")
        ),
        .package(
            url: "https://github.com/onevcat/Rainbow.git",
            .upToNextMinor(from: "4.1.0")
        ),
    ],
    targets: [
        .executableTarget(name: "SwiftFlagCleaner", dependencies: [
            .target(name: "SwiftFlagCleanerKit"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
        .target(
            name: "SwiftFlagCleanerKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(name: "FlagCleanerTests", dependencies: ["SwiftFlagCleaner"])
    ]
)
