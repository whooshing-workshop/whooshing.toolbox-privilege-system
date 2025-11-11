import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import PrivilegeModule

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(MacroImplements)
import MacroImplements
import ResourceMacros

let testMacros: [String: Macro.Type] = [
    "Resource": ResourceMacro.self,
    "Label": LabelMacro.self
]
#endif

final class MyMacroTests: XCTestCase {
    func testMacro1() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX) let owner = "100"
                let name: String
                static let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX) let owner = "100"
                let name: String
                static let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "owner": \\.owner
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro2() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource
            struct Testing: @unchecked Sendable {
                
                enum OpList: String, OperationList {
                    case asdf
                }
                
                let owner = "100"
                let name: String
                let label: any Label
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                
                enum OpList: String, OperationList {
                    case asdf
                }
                
                let owner = "100"
                let name: String
                let label: any Label
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {

                public static var vars: [String: PartialKeyPath<Self>] {
                    [:]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro3() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Label(include: .or(.lets))
            struct TestingLabel {
                let id = UUID()
                let name: String
                var testing: TT
            }
            """,
            expandedSource: """
            struct TestingLabel {
                let id = UUID()
                let name: String
                var testing: TT
            }

            extension TestingLabel: Label {

                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "id": \\.id,
                        "name": \\.name
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro4() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .or(.vars, .lets))
            struct Testing {
                let owner = "100"
                var name: String
                var label: String
                var age = 24 + 23.5
                var age2 = 24 + (23.5 + 12)
                var height = 175.6
                
                static var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing {
                let owner = "100"
                var name: String
                var label: String
                var age = 24 + 23.5
                var age2 = 24 + (23.5 + 12)
                var height = 175.6
                
                static var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "owner": \\.owner,
                        "name": \\.name,
                        "label": \\.label,
                        "age": \\.age,
                        "age2": \\.age2,
                        "height": \\.height
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro5() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .or(.lets))
            struct Testing {
                let owner = "100"
                var name: String
                var label: String
                var age = 24 + 23.5
                var age2 = 24 + (23.5 + 12)
                var height = 175.6
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing {
                let owner = "100"
                var name: String
                var label: String
                var age = 24 + 23.5
                var age2 = 24 + (23.5 + 12)
                var height = 175.6
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "owner": \\.owner
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro6() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Label(include: .or(.lets))
            struct TestingLabel {
                let id = UUID()
                static let name: String
                var testing: TT
            }
            """,
            expandedSource: """
            struct TestingLabel {
                let id = UUID()
                static let name: String
                var testing: TT
            }

            extension TestingLabel: Label {

                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "id": \\.id
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro7() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Label(include: .or(.vars, .lets))
            struct TestingLabel {
                let id = UUID()
                let name: String
                var testing: TT
            }
            """,
            expandedSource: """
            struct TestingLabel {
                let id = UUID()
                let name: String
                var testing: TT
            }

            extension TestingLabel: Label {

                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "id": \\.id,
                        "name": \\.name,
                        "testing": \\.testing
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro8() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .and(.lets))
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  static let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  static let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "label": \\.label,
                        "age": \\.age,
                        "age2": \\.age2,
                        "height": \\.height,
                        "arr": \\.arr,
                        "dic": \\.dic
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro9() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .or(.lets, .vars))
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "owner": \\.owner,
                        "name": \\.name,
                        "label": \\.label,
                        "age": \\.age,
                        "age2": \\.age2,
                        "height": \\.height,
                        "arr": \\.arr,
                        "dic": \\.dic,
                        "num": \\.num
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro10() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .or(.propertyWrappers))
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "owner": \\.owner,
                        "name": \\.name
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro11() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .and(.lets, .propertyWrappers))
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [
                        "owner": \\.owner
                    ]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testMacro12() throws {
        #if canImport(MacroImplements)
        assertMacroExpansion(
            """
            @Resource(include: .and(.lets, .vars))
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                static let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }
            """,
            expandedSource: """
            struct Testing: @unchecked Sendable {
                @SomeWrapper(XXX, XXX)  let owner = "100"
                @Wrapper2(XXX)          var name: String
                let label: String
                let age = 24 + 23.5
                static let age2 = 24 + (23.5 + 12)
                let height = 175.6
                let arr = [
                    "asdf",
                    "asdfasdfa"
                ]
                let dic: [String: Any] = [
                    "asdf": 123,
                    "daf": "adsf"
                ]
                
                var num = 123
                func asdf() {}
            }

            extension Testing: Resource {
            
                public static var vars: [String: PartialKeyPath<Self>] {
                    [:]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
