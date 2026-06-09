// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// #if 编译器版本判断宏
#if !compiler(>=6.3)
#error("本仓库使用了 Swift 6.3+ 的高级特性，请升级您的 Xcode 或 Swift 工具链至 6.3 以上版本！")
#endif

let package = Package(
    name: "whooshing.toolbox-privilege-system",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library( name: "ResourceMacros", targets: ["ResourceMacros"] ),
        .library( name: "PrivilegeSystem", targets: ["PrivilegeSystem"] ),
        .library( name: "PrivilegeModule", targets: ["PrivilegeModule"] )
    ],
    dependencies: [
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-basic.git", from: "1.5.2"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-pgsql.git", from: "1.0.7"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-opa", from: "1.0.3"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0-latest"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1")
    ],
    targets: [
        .target(
            name: "ResourceMacros",
            dependencies: [
                .target(name: "MacroImplements"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "AnyCodable", package: "AnyCodable")
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
                .product(name: "NIOAdvanced", package: "whooshing.toolbox-basic"),
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
                .product(name: "NIOAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "DataConvertable", package: "whooshing.toolbox-basic"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql"),
                .product(name: "OPA", package: "whooshing.toolbox-opa"),
                .product(name: "Logging", package: "swift-log")
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
                .product(name: "NIOAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "DataConvertable", package: "whooshing.toolbox-basic"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql"),
                .product(name: "OPA", package: "whooshing.toolbox-opa"),
                .product(name: "Logging", package: "swift-log")
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
