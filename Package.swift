// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VMTranslator",
    products: [
            .executable(
                name: "hackvmtranslator",
                targets: ["VMTranslator"]
            ),
        ],
        dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0")),
        ],
        targets: [
            .executableTarget(
                name: "VMTranslator",
                dependencies: [
                    .product(name: "ArgumentParser", package: "swift-argument-parser"),
                ],
                path: "Sources"
            ),
        ]
)
