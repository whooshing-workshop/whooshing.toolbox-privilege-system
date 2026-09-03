import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import ResourceMacros
import MacroImplements

// MARK: - 宏测试集

/// 使用 SwiftSyntaxMacrosTestSupport 对 @Resource 宏进行白盒测试，
/// 直接验证宏展开后的源代码是否符合预期，无需连接数据库或 OPA。
@Suite("@Resource 宏展开测试集")
struct MacroTests {

    let testMacros: [String: Macro.Type] = [
        "Resource": ResourceMacro.self,
    ]

    // MARK: 基础场景

    @Test("单属性结构体展开")
    func testSingleProperty() {
        assertMacroExpansion(
            """
            @Resource
            struct MyRes {
                var appId: String
            }
            """,
            expandedSource: """
            struct MyRes {
                var appId: String
            }

            extension MyRes: Resource {
                public var json: [String: AnyCodable] {
                    [
                        "name": AnyCodable(name)
                    ]
                }
                public static var mirrors: [PartialKeyPath<Self>: [String]] {
                    [
                        \\.name: ["name"]
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("多属性结构体展开")
    func testMultipleProperties() {
        assertMacroExpansion(
            """
            @Resource
            struct FileResource {
                var appId: String
                var path: String
                var isPrivate: Bool
            }
            """,
            expandedSource: """
            struct FileResource {
                var appId: String
                var path: String
                var isPrivate: Bool
            }

            extension FileResource: Resource {
                public var json: [String: AnyCodable] {
                    [
                        "appId": AnyCodable(appId),
                        "path": AnyCodable(path),
                        "isPrivate": AnyCodable(isPrivate)
                    ]
                }
                public static var mirrors: [PartialKeyPath<Self>: [String]] {
                    [
                        \\.name: ["name"],
                        \\.path: ["path"],
                        \\.isPrivate: ["isPrivate"]
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: static 属性排除

    @Test("static 属性不进入 json/mirrors")
    func testStaticPropertiesExcluded() {
        assertMacroExpansion(
            """
            @Resource
            struct DirectoryResource {
                static let type: String = "directory"
                var appId: String
                var path: String
            }
            """,
            expandedSource: """
            struct DirectoryResource {
                static let type: String = "directory"
                var appId: String
                var path: String
            }

            extension DirectoryResource: Resource {
                public var json: [String: AnyCodable] {
                    [
                        "appId": AnyCodable(appId),
                        "path": AnyCodable(path)
                    ]
                }
                public static var mirrors: [PartialKeyPath<Self>: [String]] {
                    [
                        \\.name: ["name"],
                        \\.path: ["path"]
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: 计算属性排除

    @Test("计算属性不进入 json/mirrors")
    func testComputedPropertiesExcluded() {
        assertMacroExpansion(
            """
            @Resource
            struct AliasResource {
                var appId: String
                var targetId: String
                var display: String { name + " -> " + targetId }
            }
            """,
            expandedSource: """
            struct AliasResource {
                var appId: String
                var targetId: String
                var display: String { name + " -> " + targetId }
            }

            extension AliasResource: Resource {
                public var json: [String: AnyCodable] {
                    [
                        "appId": AnyCodable(appId),
                        "targetId": AnyCodable(targetId)
                    ]
                }
                public static var mirrors: [PartialKeyPath<Self>: [String]] {
                    [
                        \\.name: ["name"],
                        \\.targetId: ["targetId"]
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: let 属性

    @Test("let 存储属性也进入 json/mirrors")
    func testLetPropertyIncluded() {
        assertMacroExpansion(
            """
            @Resource
            struct ImmutableRes {
                let name: String
                let ownerId: String
            }
            """,
            expandedSource: """
            struct ImmutableRes {
                let name: String
                let ownerId: String
            }

            extension ImmutableRes: Resource {
                public var json: [String: AnyCodable] {
                    [
                        "appId": AnyCodable(appId),
                        "ownerId": AnyCodable(ownerId)
                    ]
                }
                public static var mirrors: [PartialKeyPath<Self>: [String]] {
                    [
                        \\.name: ["name"],
                        \\.ownerId: ["ownerId"]
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: 无属性（边界）

    @Test("空结构体展开生成空字典")
    func testEmptyStruct() {
        assertMacroExpansion(
            """
            @Resource
            struct EmptyRes {
            }
            """,
            expandedSource: """
            struct EmptyRes {
            }

            extension EmptyRes: Resource {
                public var json: [String: AnyCodable] {
                    [:]
                }
                public static var mirrors: [PartialKeyPath<Self>: [String]] {
                    [:]
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: 诊断：错误类型

    @Test("非 struct/class 应产生编译错误")
    func testEnumProducesDiagnostic() {
        assertMacroExpansion(
            """
            @Resource
            enum BadRes {
                case a
            }
            """,
            expandedSource: """
            enum BadRes {
                case a
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Resource 宏只能应用于 struct 或 class", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
