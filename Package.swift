// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "whooshing.toolbox-privilege-system",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library( name: "ResourceMacros", targets: ["ResourceMacros"] ),
        .library( name: "PrivilegeSystem", targets: ["PrivilegeSystem"] ),
        .library( name: "PrivilegeModule", targets: ["PrivilegeModule"] )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0-latest"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-basic.git", from: "1.5.2"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-pgsql.git", from: "1.0.7"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-opa", from: "1.0.2")
    ],
    targets: [
        .target(
            name: "ResourceMacros",
            dependencies: [
                .target(name: "MacroImplements")
            ]
        ),
        .target(
            name: "Policy",
            dependencies: [
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql"),
            ]
        ),
        .target(
            name: "Query",
            dependencies: [
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql")
            ]
        ),
        .target(
            name: "PrivilegeSystem",
            dependencies: [
                .target(name: "Query"),
                .target(name: "Policy"),
                .target(name: "PrivilegeModule"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql"),
                .product(name: "OPA", package: "whooshing.toolbox-opa")
            ],
            resources: [
                .copy("SQLFunctions"),
                .copy("Regos")
            ]
        ),
        .target(
            name: "PrivilegeModule",
            dependencies: [
                .target(name: "Query"),
                .target(name: "Policy"),
                .target(name: "ResourceMacros"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql"),
                .product(name: "OPA", package: "whooshing.toolbox-opa")
            ]
        ),
        .macro(
            name: "MacroImplements",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "toolbox-privilege-system-Tests",
            dependencies: [
                .target(name: "PrivilegeSystem"),
                .target(name: "PrivilegeModule"),
                .target(name: "MacroImplements"),
                .target(name: "Query"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        )
    ]
)
