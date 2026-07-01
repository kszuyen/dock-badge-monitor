// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BadgeBell",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BadgeBell", targets: ["BadgeBell"])
    ],
    targets: [
        .executableTarget(
            name: "BadgeBell",
            path: "Sources/BadgeBell"
        ),
        .testTarget(
            name: "BadgeBellTests",
            dependencies: ["BadgeBell"]
        )
    ]
)
