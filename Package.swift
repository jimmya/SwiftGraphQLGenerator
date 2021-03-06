// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGraphQLGenerator",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(name: "swift-graphql-generator", targets: ["generator"]),
        .library(
            name: "SwiftGraphQLGenerator",
            targets: ["SwiftGraphQLGenerator"]),
        .executable(name: "Validator", targets: ["Validator"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/GraphQLSwift/GraphQL", .upToNextMajor(from: .init(0, 12, 0))),
        .package(url: "https://github.com/jimmya/Meta.git", .branch("master")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: .init(0, 0, 1))),
        .package(url: "https://github.com/onevcat/Rainbow", .upToNextMajor(from: .init(3, 0, 0))),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "generator",
                dependencies: [
                    "SwiftGraphQLGenerator",
                    .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SwiftGraphQLGenerator",
            dependencies: [
                .product(name: "GraphQL", package: "GraphQL"),
                .product(name: "Meta", package: "Meta"),
                .product(name: "Rainbow", package: "Rainbow"),
        ]),
        .target(
            name: "Validator"),
        .testTarget(
            name: "GraphQLGeneratorTests",
            dependencies: ["SwiftGraphQLGenerator"]),
    ]
)
