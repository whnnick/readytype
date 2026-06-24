// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ReadyType",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReadyType", targets: ["ReadyType"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ReadyType",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "ReadyType/ReadyType",
            resources: [
                .copy("Resources/ReadyTypeInfo.plist"),
                .copy("Resources/ReadyTypeMenuBarTemplate.png"),
                .copy("Resources/ReadyTypeAppIcon.icns"),
                .copy("Resources/ReadyTypeAppIcon.iconset"),
                .copy("Resources/ReadyTypeBrandLogo.svg")
            ]
        ),
        .testTarget(
            name: "ReadyTypeTests",
            dependencies: ["ReadyType"],
            path: "ReadyType/ReadyTypeTests"
        )
    ]
)
