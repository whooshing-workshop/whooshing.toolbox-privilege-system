import ErrorHandle

extension Censor.Symbol {
    typealias GenericReturns = @Sendable ([any Censor.TypeDeclare]) -> Res<any Censor.TypeDeclare, Censor.Errcase>
    protocol Sugar: Operator {
        var name: String { get }
        var returns: GenericReturns { get }
        var argumentCount: Int { get }
        var action: Censor.ExecutableAction { get }
    }
    
    static let sugars: [Sugar] = [
        Not(),
        ForceCast(),
        OptionalChaining(),
        NilCoalescing(),
        Ternary()
    ]
}

extension Censor.Symbol.Sugar {
    var description: String { "Symbol.\(name)" }
}

// MARK: - Sugar Defines

extension Censor.Symbol {
    struct Not: Sugar, Prefix {
        let name = "NOT"
        let lexeme = "!"
        let argumentCount = 1
        
        let returns: GenericReturns = {
            guard $0.count == 1, let variable = $0.first else {
                return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 1 个，却得到 \($0.count) 个", category: .internal)
            }

            guard variable is Censor.BoolType, !variable.nullable else {
                return .failure(.sugarTypeDetectFailed, "取反操作仅当应用在 Boolean")
            }

            return .success(variable)
        }
        
        let action = Censor.ExecutableAction { .succ(!$0[0].cast(as: Bool.self)) }
    }

    struct ForceCast: Sugar, Postfix {
        let name = "F_CAST"
        let lexeme = "!"
        let allowRepeating = true
        let argumentCount = 1
        
        let returns: GenericReturns = {
            guard $0.count == 1, let variable = $0.first else {
                return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 1 个，却得到 \($0.count) 个", category: .internal)
            }

            guard variable.nullable else {
                return .failure(.sugarTypeDetectFailed, "强制解包仅当应用在可选值", category: .external)
            }

            return .success(variable.set(nullable: false))
        }
        
        let action = Censor.ExecutableAction { .succ($0[0].content!) }
    }

    struct OptionalChaining: Sugar, Postfix {
        let name = "OP_CHAIN"
        let lexeme = "?"
        let argumentCount = 1
        
        let returns: GenericReturns = { _ in
            fatalError()
        }
        
        let action = Censor.ExecutableAction { _ in fatalError() }
    }

    struct NilCoalescing: Sugar, Infix {
        let name = "NIL_COAL"
        let lexeme = "??"
        let precedence: AnyPrecedence = Precedence.NilCoalescing().any
        let argumentCount = 2
        
        let returns: GenericReturns = {
            guard
                $0.count == 2,
                let origin = $0.first,
                let instead = $0.last
            else {
                return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 2 个，却得到 \($0.count) 个", category: .internal)
            }

            let name1 = type(of: origin).name
            let name2 = type(of: instead).name

            guard name1 == name2 else {
                return .failure(.sugarTypeDetectFailed, "值类型不一致，预期为 \(name1) ?? \(name1), 却得到 \(name1) ?? \(name2)", category: .external)
            }

            guard origin.nullable else {
                return .failure(.sugarTypeDetectFailed, "空值替代仅应当作用于可选值", category: .external)
            }

            return .success(instead)
        }
        
        let action = Censor.ExecutableAction { .succ($0[0].content ?? $0[1].content) }
    }

    struct Ternary: Sugar, Vary {
        
        struct Question: Operator, Infix, CustomStringConvertible {
            let lexeme = "?"
            let precedence: AnyPrecedence = Precedence.Ternary().any
            
            let description = "Symbol.TERNARY_QUEST"
        }

        struct Colon: Operator, Infix, CustomStringConvertible {
            let lexeme = ":"
            let precedence: AnyPrecedence = Precedence.Ternary().any
            
            let description = "Symbol.TERNARY_COLON"
        }

        let symbols: [Censor.Symbol.Operator] = [Question(), Colon()]
        
        let argumentCount = 3
        
        let returns: GenericReturns = {
            guard $0.count == 3 else {
                return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 3 个，却得到 \($0.count) 个", category: .internal)
            }

            guard $0.first is Censor.BoolType else {
                return .failure(.sugarTypeDetectFailed, "判断值应当为 Bool，却得到 \(String(describing: type(of: $0[0]).name))", category: .external)
            }

            let pass = $0[1]
            let fail = $0[2]

            let name2 = type(of: pass).name
            let name3 = type(of: fail).name

            guard name2 == name3 else {
                return .failure(.sugarTypeDetectFailed, "值类型不一致，预期为 \(name2) : \(name2), 却得到 \(name2) : \(name3)", category: .external)
            }

            let nullable = pass.nullable || fail.nullable

            return .success(pass.set(nullable: nullable))
        }
        
        let action = Censor.ExecutableAction { .succ( ($0[0].content as! Bool) ? $0[1] : $0[2] ) }
        
        var description: String { fatalError("Vary 不应当被直接调用") }
    }
}
