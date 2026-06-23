// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FocusSlot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FocusSlotCore", targets: ["FocusSlotCore"]),
        .executable(name: "FocusSlot", targets: ["FocusSlot"])
    ],
    targets: [
        .target(
            name: "FocusSlotCore",
            path: "Sources/FocusSlotCore"
        ),
        .executableTarget(
            name: "FocusSlot",
            dependencies: ["FocusSlotCore"],
            path: "Sources/FocusSlot"
        ),
        .testTarget(
            name: "FocusSlotCoreTests",
            dependencies: ["FocusSlotCore"],
            path: "Tests/FocusSlotCoreTests"
        )
    ]
)
