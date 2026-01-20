// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JiraMacNotifier",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "JiraMacNotifier",
            targets: ["JiraMacNotifier"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "JiraMacNotifier",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/JiraMacNotifier"
        ),
        .testTarget(
            name: "JiraMacNotifierTests",
            dependencies: ["JiraMacNotifier"],
            path: "Tests/JiraMacNotifierTests"
        )
    ]
)
