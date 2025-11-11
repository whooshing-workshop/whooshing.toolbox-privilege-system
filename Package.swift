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
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.7"),
//        .package(url: "https://github.com/SJJC-Team/whooshing.toolbox-basic.git", .upToNextMajor(from: "1.4.4")),
        .package(path: "/Users/clwang/GitHub/whooshing.toolbox-basic"),
//        .package(url: "https://github.com/SJJC-Team/whooshing.toolbox-pgsql.git", .upToNextMajor(from: "1.0.5"))
        .package(path: "/Users/clwang/GitHub/whooshing.toolbox-pgsql")
    ],
    targets: [
        .target(name: "ResourceMacros", dependencies: ["MacroImplements"]),
        .target(
            name: "PrivilegeSystem",
            dependencies: [
                .target(name: "ACL"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql")
            ]
        ),
        .target(
            name: "PrivilegeModule",
            dependencies: [
                .target(name: "ResourceMacros"),
                .target(name: "ACL"),
                .product(name: "AnyCodable", package: "AnyCodable"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql")
            ]
        ),
        .target(
            name: "ACL",
            dependencies: [
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql")
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
                .target(name: "MacroImplements"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "toolbox-privilege-module-Tests",
            dependencies: [
                .target(name: "PrivilegeModule"),
                .target(name: "MacroImplements"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        )
    ]
)
