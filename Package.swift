// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LockScreenMirror",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LockScreenMirror",
            targets: ["LockScreenMirror"]
        )
    ],
    targets: [
        .target(
            name: "LockScreenMirror",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)