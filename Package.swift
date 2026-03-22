// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MacJunkScanner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacJunkScanner",
            targets: ["MacJunkScanner"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacJunkScanner",
            path: "Sources"
        )
    ]
)
