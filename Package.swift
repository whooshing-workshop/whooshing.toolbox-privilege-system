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
        .library( name: "PrivilegeModuleExtended", targets: ["PrivilegeModuleExtended", "ResourceMacros"] ),
        .library( name: "PrivilegeSystem", targets: ["PrivilegeSystem", "ResourceMacros"] ), // 必须显式声明依赖 ResourceMacros，否则编译会报错：Target MacroImplements imports another target (SwiftCompilerPlugin) in the package without declaring it a dependency.
        .library( name: "PrivilegeModule", targets: ["PrivilegeModule", "ResourceMacros"] )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", from: "4.122.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0-latest"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.3"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-opa", from: "1.0.5"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-basic.git", from: "1.6.3"),
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-pgsql.git", from: "1.1.3"),
    ],
    targets: [
        .target(
            name: "ResourceMacros",
            dependencies: [
                .target(name: "MacroImplements"),
                .target(name: "ResourceDefine"),
                // 必须显式声明依赖，否则编译会报错：Target MacroImplements imports another target (SwiftCompilerPlugin) in the package without declaring it a dependency.
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .target(
            name: "Query",
            dependencies: [
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql")
            ]
        ),
        .target(
            name: "DTOBuilder",
            dependencies: [
                .target(name: "Query")
            ]
        ),
        .target(
            name: "ResourceDefine",
            dependencies: [
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic")
            ]
        ),
        .target(
            name: "PrivilegeModule",
            dependencies: [
                .target(name: "DTOBuilder"),
                .target(name: "ResourceDefine"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "OPA", package: "whooshing.toolbox-opa")
            ]
        ),
        .target(
            name: "PrivilegeModuleExtended",
            dependencies: [
                .target(name: "PrivilegeModule")
            ]
        ),
        .target(
            name: "PrivilegeSystem",
            dependencies: [
                .target(name: "PrivilegeModuleExtended")
            ],
            resources: [
                .copy("SQLFunctions"),
                .copy("Regos")
            ]
        ),
        .macro(
            name: "MacroImplements",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "toolbox-privilege-system-Tests",
            dependencies: [
                .target(name: "PrivilegeSystem"),
                .target(name: "PrivilegeModule"),
                .target(name: "ResourceMacros"),
                .target(name: "DTOBuilder"),
                .target(name: "PrivilegeModuleExtended"),
                .target(name: "Query"),
                .target(name: "MacroImplements"),
                .product(name: "VaporTesting", package: "Vapor"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        )
    ]
)
