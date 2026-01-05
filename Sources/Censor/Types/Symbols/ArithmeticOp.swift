import Foundation

extension Censor.Symbol {
    protocol Operator: Define {
        var precedence: AnyPrecedence { get }
    }
    
    protocol ArithmeticOp: Operator {}
    
    public enum InfixOperator: String, Sendable, Codable, CaseIterable {
        case plus
        case minus
        case multi
        case divide
        case mode
        case exp
        case equal
        case less
        case and
        case or
        case notEqual
        case greater
        case lessEqual
        case greaterEqual
        
        case nilCoalescing
        case ternary
        case dot

        var `operator`: any Operator {
            switch self {
            case .plus: Plus()
            case .minus: Minus()
            case .multi: Multi()
            case .divide: Divide()
            case .mode: Mode()
            case .exp: Exp()
            case .equal: Equal()
            case .less: Less()
            case .and: And()
            case .or: Or()
            case .notEqual: NotEqual()
            case .greater: Greater()
            case .lessEqual: LessEqual()
            case .greaterEqual: GreaterEqual()
                
            case .nilCoalescing: NilCoalescing()
            case .ternary: Ternary()
            case .dot: Dot()
            }
        }
    }
    
    public enum PrefixOperator: String, Sendable, Codable, CaseIterable {
        case positive
        case negative
        
        case not
        
        var `operator`: any Operator {
            switch self {
            case .positive: Positive()
            case .negative: Negetive()
                
            case .not: Not()
            }
        }
    }
    
    public enum PostfixOperator: String, Sendable, Codable, CaseIterable {
        case forceCast
        case optionalChaining
        
        var `operator`: any Operator {
            switch self {
            case .forceCast: ForceCast()
            case .optionalChaining: OptionalChaining()
            }
        }
    }
}

extension Censor.Symbol.Operator where Self: Censor.Symbol.Prefix {
    var precedence: Censor.Symbol.AnyPrecedence { Censor.Symbol.Precedence.Prefix().any }
    var description: String { "Symbol.Prefix(\(lexeme))" }
}

extension Censor.Symbol.Operator where Self: Censor.Symbol.Postfix {
    var precedence: Censor.Symbol.AnyPrecedence { Censor.Symbol.Precedence.Postfix().any }
    var description: String { "Symbol.Postfix(\(lexeme))" }
}

extension Censor.Symbol.Operator where Self: Censor.Symbol.Infix {
    var description: String { "Symbol.Infix(\(lexeme))" }
}

// MARK: - Prefix Operator Defines

extension Censor.Symbol {
    struct Positive: ArithmeticOp, Hashable, Prefix {
        let lexeme = "+"
    }
    
    struct Negetive: ArithmeticOp, Hashable, Prefix {
        let lexeme = "-"
    }
}

// MARK: - Infix Operator Defines

extension Censor.Symbol {
    struct Plus: ArithmeticOp, Hashable, Infix {
        let lexeme = "+"
        let precedence: AnyPrecedence = Precedence.Addition().any
    }
    
    struct Minus: ArithmeticOp, Hashable, Infix {
        let lexeme = "-"
        let precedence: AnyPrecedence = Precedence.Addition().any
    }
    
    struct Multi: ArithmeticOp, Hashable, Infix {
        let lexeme = "*"
        let precedence: AnyPrecedence = Precedence.Multiplication().any
    }
    
    struct Divide: ArithmeticOp, Hashable, Infix {
        let lexeme = "/"
        let precedence: AnyPrecedence = Precedence.Multiplication().any
    }
    
    struct Mode: ArithmeticOp, Hashable, Infix {
        let lexeme = "%"
        let precedence: AnyPrecedence = Precedence.Multiplication().any
    }
    
    struct Exp: ArithmeticOp, Hashable, Infix {
        let lexeme = "^"
        let precedence: AnyPrecedence = Precedence.Exponentiation().any
    }
    
    struct Equal: ArithmeticOp, Hashable, Infix {
        let lexeme = "=="
        let precedence: AnyPrecedence = Precedence.Comparison().any
    }
    
    struct Less: ArithmeticOp, Hashable, Infix {
        let lexeme = "<"
        let precedence: AnyPrecedence = Precedence.Comparison().any
    }
    
    struct And: ArithmeticOp, Hashable, Infix {
        let lexeme = "&"
        let precedence: AnyPrecedence = Precedence.LogicAnd().any
    }
    
    struct Or: ArithmeticOp, Hashable, Infix {
        let lexeme = "|"
        let precedence: AnyPrecedence = Precedence.LogicOr().any
    }

    struct Dot: ArithmeticOp, Hashable, Infix {
        let lexeme = "."
        let spacing: Spacing = .any
        let precedence: AnyPrecedence = Precedence.Postfix().any
    }
}

extension Censor.Symbol {
    struct NotEqual: ArithmeticOp, Alias, Infix {
        let lexeme = "!="
        let precedence: AnyPrecedence = Precedence.Comparison().any
        let aliasAs: [any Define] = [Not(), Equal()]
    }
    
    struct GreaterEqual: ArithmeticOp, Alias, Infix {
        let lexeme = ">="
        let precedence: AnyPrecedence = Precedence.Comparison().any
        let aliasAs: [any Define] = [Not(), Less()]
    }
    
    struct LessEqual: ArithmeticOp, Alias, Infix {
        let lexeme = "<="
        let precedence: AnyPrecedence = Precedence.Comparison().any
        let aliasAs: [any Define] = [Less(), Equal()]
    }
    
    struct Greater: ArithmeticOp, Alias, Infix {
        let lexeme = ">"
        let precedence: AnyPrecedence = Precedence.Comparison().any
        let aliasAs: [any Define] = [Not(), LessEqual()]
    }
}
