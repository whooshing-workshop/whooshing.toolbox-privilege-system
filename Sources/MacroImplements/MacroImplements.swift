import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ResourceMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        try ExtensionExpansion(
            protocolName: "Resource",
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
    }
}

public struct LabelMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        try ExtensionExpansion(
            protocolName: "Label",
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
    }
}

func ExtensionExpansion(
    protocolName: String,
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext,
    extraMember: () throws -> String = { "" }
) throws -> [ExtensionDeclSyntax] {
    
    guard
        declaration.is(StructDeclSyntax.self) ||
        declaration.is(ClassDeclSyntax.self)
    else {
        fatalError("编译失败：该宏定义的对象仅能是 struct 或 class")
    }
    
    var includeVars = false
    var includeLets = false
    var includePropertyWrappers = false
    var andStratege = false
    
    if let funcCall = node
        .arguments?
        .as(LabeledExprListSyntax.self)?
        .first?
        .expression
        .as(FunctionCallExprSyntax.self),
       let funcName = funcCall
        .calledExpression
        .as(MemberAccessExprSyntax.self)?
        .declName
        .baseName
        .text
    {
        andStratege = funcName == "and"
        
        for element in funcCall.arguments {
            guard let enumName = element.expression
                .as(MemberAccessExprSyntax.self)?
                .declName
                .baseName
                .identifier?
                .name
            else {
                continue
            }
            
            switch enumName {
            case "lets": includeLets = true
            case "vars": includeVars = true
            case "propertyWrappers": includePropertyWrappers = true
            default: continue
            }
        }
    } else {
        includeLets = false
        includeVars = false
        includePropertyWrappers = true
        andStratege = false
    }
    
    let includeOperation: (VariableDeclSyntax) -> Bool = { decl in
        var res = true
        if andStratege {
            if includeLets { res = res && decl.bindingSpecifier.trimmedDescription == "let" }
            if includeVars { res = res && decl.bindingSpecifier.trimmedDescription == "var" }
            if includePropertyWrappers { res = res && decl.attributes.count > 0 }
            return res
        } else {
            return (
                (includeLets && decl.bindingSpecifier.trimmedDescription == "let") ||
                (includeVars && decl.bindingSpecifier.trimmedDescription == "var") ||
                (includePropertyWrappers && decl.attributes.count > 0)
            )
        }
    }
    
    let members = Array(declaration.memberBlock.members)
    
    var keypaths: [String] = []
    for member in members {
        guard
            let variableDecl = member.decl.as(VariableDeclSyntax.self),
            !variableDecl.modifiers.contains(where: { $0.name.text == "static" }),
            includeOperation(variableDecl),
            let binding = variableDecl.bindings.first
        else {
            continue
        }
        
        let varName = binding.pattern.trimmedDescription
        
        keypaths.append("""
        "\(varName)": \\.\(varName)
        """)
    }
    
    let res: DeclSyntax = try """
    extension \(type.trimmed): \(raw: protocolName) {
        \(raw: extraMember())
        public static var vars: [String: PartialKeyPath<Self>] {\(raw: keypaths.count == 0 ? "[:]" : "[\n\(keypaths.joined(separator: ",\n"))\n]")}
    }
    """
    
    guard let extensionDecl = res.as(ExtensionDeclSyntax.self) else {
        fatalError("编译错误：无法生成 extension")
    }

    return [extensionDecl]
}

/// 根据 ExprSyntax 推断类型，返回字符串表示的类型
func inferTypeString(from expr: ExprSyntax) -> String {
    
    if expr.is(IntegerLiteralExprSyntax.self) {
        return "Int"
    } else if expr.is(FloatLiteralExprSyntax.self) {
        return "Double"
    } else if expr.is(StringLiteralExprSyntax.self) {
        return "String"
    } else if expr.is(BooleanLiteralExprSyntax.self) {
        return "Bool"
    } else if let arrayExpr = expr.as(ArrayExprSyntax.self) {
        var t: String? = nil
        for element in arrayExpr.elements {
            let type = inferTypeString(from: element.expression)
            if let resT = t {
                if resT != type {
                    t = nil
                    break
                }
            } else {
                t = type
            }
        }
        
        return "[\(t ?? "Any")]"
    } else if let dictExpr = expr.as(DictionaryExprSyntax.self) {
        guard let elements = dictExpr.content.as(DictionaryElementListSyntax.self) else {
            return "[AnyHashable: Any]"
        }
        
        var keyT: String? = nil
        var kSetted = false
        var valueT: String? = nil
        var vSetted = false
        for element in elements {
            let keyType = inferTypeString(from: element.key)
            let valueType = inferTypeString(from: element.value)
            
            if !kSetted {
                if let kt = keyT {
                    if kt != keyType {
                        keyT = nil
                        kSetted = true
                    }
                } else {
                    keyT = keyType
                }
            }
            
            if !vSetted {
                if let vt = valueT {
                    if vt != valueType {
                        valueT = nil
                        vSetted = true
                    }
                } else {
                    valueT = valueType
                }
            }
            
            if kSetted && vSetted { break }
        }
        
        return "[\(keyT ?? "AnyHashable"): \(valueT ?? "Any")]"
    } else if let tupleExpr = expr.as(TupleExprSyntax.self) {
        let types = tupleExpr.elements.map { inferTypeString(from: $0.expression) }
        return "(\(types.joined(separator: ", ")))"
    } else if expr.is(NilLiteralExprSyntax.self) {
        return "NULL"
    } else {
        return "Unknown"
    }
}

@main
struct MyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResourceMacro.self,
        LabelMacro.self
    ]
}
