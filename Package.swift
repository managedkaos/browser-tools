// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "browsers",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "browsers", targets: ["browsers"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.8.2"),
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2"),
    ],
    targets: [
        .target(
            name: "BrowsersCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .executableTarget(
            name: "browsers",
            dependencies: [
                "BrowsersCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "BrowsersCoreTests",
            dependencies: ["BrowsersCore"]
        ),
    ]
)
