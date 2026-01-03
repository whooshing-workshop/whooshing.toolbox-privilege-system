import ErrorHandle

public extension Censor {
    struct Sugar: Sendable {
        public let returns: @Sendable ([any TypeDeclare]) -> Res<any TypeDeclare, Errcase>
        public let argumentCount: Int
        public let precedence: Operator.Precedence.Declare.Type
        public let action: ExecutableAction
        let lexemes: [Censor.Compiler.Token]
        
        init(
            lexemes: [Censor.Compiler.Token],
            returns: @Sendable @escaping ([any TypeDeclare]) -> Res<any TypeDeclare, Errcase>,
            argumentCount: Int,
            precedence: Operator.Precedence.Declare.Type,
            action: ExecutableAction
        ) {
            self.lexemes = lexemes
            self.returns = returns
            self.argumentCount = argumentCount
            self.precedence = precedence
            self.action = action
        }
        
        public init(@SugarBuilder _ content: () -> Sugar) {
            self = content()
        }
    }
    
    @resultBuilder
    internal struct SugarBuilder {
        static func buildBlock(
            _ lexemes: [Censor.Compiler.Token],
            _ returns: @Sendable @escaping ([any TypeDeclare]) -> Res<any TypeDeclare, Errcase>,
            _ argumentCount: Int,
            _ precedence: Operator.Precedence.Declare.Type,
            _ action: ExecutableAction
        ) -> Sugar {
            Sugar(lexemes: lexemes, returns: returns, argumentCount: argumentCount, precedence: precedence, action: action)
        }
    }
    
    static func ArgumentCount(_ count: @Sendable @escaping () -> Int) -> Int { count() }
    static func PrecedenceSet(_ content: @Sendable @escaping () -> Operator.Precedence.Declare.Type) -> Operator.Precedence.Declare.Type { content() }
    static func GenericReturn(_ content: @Sendable @escaping ([any TypeDeclare]) -> Res<any TypeDeclare, Errcase>) -> @Sendable ([any TypeDeclare]) -> Res<any TypeDeclare, Errcase> { content }
}

public extension Censor {
    internal typealias Token = Censor.Compiler.Token
    internal typealias Symbol = Censor.Compiler.Token.Symbol
    enum SugarKey: Hashable, Sendable {
        
        public enum TernaryPart: String, Sendable, CaseIterable, CustomStringConvertible {
            case question = "QUEST"
            case colon = "COLON"
            
            public var description: String { self.rawValue }
        }
        
        case not
        case forceCast
        case nilCoalescing
        case optionalChaining
        case ternary(TernaryPart)
        
        public var sugar: Sugar {
            switch self {
            case .not: .init {
                [
                    Token("!", Symbol.sugar(.not), .prefix, spacing: .asym(true))
                ]
                GenericReturn {
                    guard $0.count == 1, let variable = $0.first else {
                        return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 1 个，却得到 \($0.count) 个", category: .internal)
                    }
                    
                    guard variable is BoolType, !variable.nullable else {
                        return .failure(.sugarTypeDetectFailed, "取反操作仅当应用在 Boolean")
                    }
                    
                    return .success(variable)
                }
                ArgumentCount { 1 }
                PrecedenceSet { Operator.Precedence.Prefix.self }
                ExecutableAction { .succ(!$0.first!.cast(as: Bool.self)) }
            }
            case .forceCast: .init {
                [
                    Token("!", Symbol.sugar(.forceCast), .postfix, spacing: .asym(false), allowRepeating: true)
                ]
                GenericReturn {
                    guard $0.count == 1, let variable = $0.first else {
                        return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 1 个，却得到 \($0.count) 个", category: .internal)
                    }
                    
                    guard variable.nullable else {
                        return .failure(.sugarTypeDetectFailed, "强制解包仅当应用在可选值", category: .external)
                    }
                    
                    return .success(variable.set(nullable: false))
                }
                ArgumentCount { 1 }
                PrecedenceSet { Operator.Precedence.Postfix.self }
                ExecutableAction { .succ($0.first!.content!) }
            }
            case .nilCoalescing: .init {
                [
                    Token("??", Symbol.sugar(.nilCoalescing), .postfix, spacing: .symm(nil))
                ]
                GenericReturn {
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
                ArgumentCount { 2 }
                PrecedenceSet { Operator.Precedence.NilCoalescing.self }
                ExecutableAction { .succ($0.first!.content ?? $0.last!.content) }
            }
            case .optionalChaining: .init {
                [
                    Token("?", Symbol.sugar(.optionalChaining), .postfix, spacing: .asym(false)),
                ]
                GenericReturn { _ in
                    fatalError()
                }
                ArgumentCount { 1 }
                PrecedenceSet { Operator.Precedence.Postfix.self }
                ExecutableAction { _ in fatalError() }
            }
            case .ternary: .init {
                [
                    Token("?", Symbol.sugar(.ternary(.question)), .infix, spacing: .symm(true), allowRepeating: true),
                    Token(":", Symbol.sugar(.ternary(.colon)), .infix, spacing: .symm(true))
                ]
                GenericReturn {
                    guard $0.count == 3 else {
                        return .failure(.sugarTypeDetectFailed, "传入的参数不合法，预期为 3 个，却得到 \($0.count) 个", category: .internal)
                    }
                    
                    guard $0.first is BoolType else {
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
                ArgumentCount { 3 }
                PrecedenceSet { Operator.Precedence.Ternary.self }
                ExecutableAction { .succ( ($0[0].content as! Bool) ? $0[1] : $0[2] ) }
            }
            }
        }
    }
}

extension Censor.SugarKey: CaseIterable {
    public static var allCases: [Censor.SugarKey] {
        [.not, .forceCast, .optionalChaining, .nilCoalescing] + Self.TernaryPart.allCases.map { .ternary($0) }
    }
}

extension Censor.SugarKey: CustomStringConvertible {
    public var description: String {
        switch self {
        case .not: "NOT"
        case .forceCast: "F_CAST"
        case .nilCoalescing: "NIL_COAL"
        case .optionalChaining: "OP_CHAIN"
        case .ternary(let part): "TERNARY_\(part)"
        }
    }
}
