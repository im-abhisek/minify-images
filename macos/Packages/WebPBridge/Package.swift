// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WebPBridge",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "WebPBridge", targets: ["WebPBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "WebPBridge",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
    ]
)
