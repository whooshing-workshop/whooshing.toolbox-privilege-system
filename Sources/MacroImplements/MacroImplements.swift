import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - ResourceMacro

/// 为 struct/class 生成 `Resource` 协议中 `json` 与 `mirrors` 的实现。
/// 扫描所有非 static 的存储属性（包括带属性包装器的属性），
/// 按属性名生成对应的 AnyCodable 条目（json）和 KeyPath 映射（mirrors）。
public struct ResourceMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard
            declaration.is(StructDeclSyntax.self) ||
            declaration.is(ClassDeclSyntax.self)
        else {
            throw MacroError.notStructOrClass
        }

        // 收集所有非 static 的存储属性名
        let propNames = storedPropertyNames(in: declaration)

        // 构造 json 字典内容，例如：
        //   "name": AnyCodable(name),
        let jsonEntries = propNames
            .map { "            \"\($0)\": AnyCodable(\($0))" }
            .joined(separator: ",\n")

        let jsonBody: String
        if propNames.isEmpty {
            jsonBody = "[:]"
        } else {
            jsonBody = "[\n\(jsonEntries)\n        ]"
        }

        // 构造 mirrors 字典内容，例如：
        //   \.name: ["name"],
        let mirrorEntries = propNames
            .map { "            \\.\($0): [\"\($0)\"]" }
            .joined(separator: ",\n")

        let mirrorsBody: String
        if propNames.isEmpty {
            mirrorsBody = "[:]"
        } else {
            mirrorsBody = "[\n\(mirrorEntries)\n        ]"
        }

        let extensionSrc: DeclSyntax = """
        extension \(type.trimmed): Resource {
            public var json: [String: AnyCodable] {
                \(raw: jsonBody)
            }
            public static var mirrors: [PartialKeyPath<Self>: [String]] {
                \(raw: mirrorsBody)
            }
        }
        """

        guard let extensionDecl = extensionSrc.as(ExtensionDeclSyntax.self) else {
            throw MacroError.expansionFailed
        }

        return [extensionDecl]
    }

    // MARK: - Helpers

    /// 返回 DeclGroupSyntax 中所有非 static 存储属性的名称（按声明顺序）。
    private static func storedPropertyNames(in declaration: some DeclGroupSyntax) -> [String] {
        declaration.memberBlock.members.compactMap { member -> String? in
            guard
                let varDecl = member.decl.as(VariableDeclSyntax.self),
                // 排除 static 属性
                !varDecl.modifiers.contains(where: { $0.name.text == "static" }),
                // 排除计算属性（有 getter body）
                let binding = varDecl.bindings.first,
                !isComputedProperty(binding),
                let nameToken = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                return nil
            }
            return nameToken.identifier.text
        }
    }

    /// 若绑定带有 getter（accessor block），则为计算属性。
    private static func isComputedProperty(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessor = binding.accessorBlock else { return false }
        switch accessor.accessors {
        case .accessors:
            return true
        case .getter:
            return true
        }
    }
}

// MARK: - MacroError

enum MacroError: Error, CustomStringConvertible {
    case notStructOrClass
    case expansionFailed

    var description: String {
        switch self {
        case .notStructOrClass:
            return "@Resource 宏只能应用于 struct 或 class"
        case .expansionFailed:
            return "@Resource 宏展开失败，无法生成 extension 代码"
        }
    }
}

// MARK: - Plugin

@main
struct ResourceMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResourceMacro.self,
    ]
}
