// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BeautifulMermaid",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .macCatalyst(.v15)
    ],
    products: [
        .library(name: "BeautifulMermaid", targets: ["BeautifulMermaid"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lukilabs/dagre-swift", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "BeautifulMermaid",
            dependencies: [.product(name: "SwiftDagre", package: "dagre-swift")]
        ),
        .testTarget(
            name: "BeautifulMermaidTests",
            dependencies: ["BeautifulMermaid"],
            resources: [.copy("layouts-reference.json")]
        ),
    ]
)
