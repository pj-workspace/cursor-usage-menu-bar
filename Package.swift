// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorUsageMenuBar",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "CursorUsageMenuBar",
            path: "Sources/CursorUsageMenuBar"
        ),
    ]
)
