// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VerIDCommonTypes",
    platforms: [.iOS(.v13), .macCatalyst(.v14), .macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "VerIDCommonTypes",
            type: .dynamic,
            targets: ["VerIDCommonTypes"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/JSONSchema.swift.git", from: "0.6.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "VerIDCommonTypes"),
        .testTarget(
            name: "VerIDCommonTypesTests",
            dependencies: ["VerIDCommonTypes", .product(name: "JSONSchema", package: "JSONSchema.swift")],
            resources: [
                .process("Resources")
            ]),
    ]
)
