// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Webview",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Webview",
            targets: ["Webview"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.0"),
        .package(path: "../Cedar"),
        .package(path: "../Canopy"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Webview",
            dependencies: [
                "AnyCodable",
                "Cedar",
                "Canopy",
            ]),

    ]
)
