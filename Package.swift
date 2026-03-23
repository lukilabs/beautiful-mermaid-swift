// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BeautifulMermaidSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .macCatalyst(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "BeautifulMermaid", targets: ["BeautifulMermaid"]),
        .executable(name: "MermaidPlayground", targets: ["MermaidPlayground"])
    ],
    dependencies: [
        .package(url: "https://github.com/lukilabs/elk-swift", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "BeautifulMermaid",
            dependencies: [
                .product(name: "ElkSwift", package: "elk-swift")
            ],
            path: "Sources/BeautifulMermaidSwift"
        ),
        .executableTarget(
            name: "MermaidPlayground",
            dependencies: ["BeautifulMermaid"],
            path: "Examples/MermaidPlayground",
            exclude: [
                "Info.plist",
                "Scripts"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BeautifulMermaidSwiftTests",
            dependencies: ["BeautifulMermaid"]
        )
    ]
)
