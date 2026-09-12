// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FaceIDMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FaceIDMac",
            targets: ["FaceIDMac"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FaceIDMac",
            dependencies: [],
            path: "Sources/FaceIDMac",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
