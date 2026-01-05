extension Censor {
    public enum Symbol {
        internal protocol Define: TokenUnit, Sendable {
            var lexeme: String { get }
            var spacing: Spacing { get }
            var allowRepeating: Bool { get }
        }
        
        internal protocol Alias {
            var aliasAs: [any Define] { get }
        }
    }
    
    static let symbols: [Symbol.Define] = {
        let symbols: [Symbol.Define] = Symbol.delimiters +
            Symbol.InfixOperator.allCases.map { $0.operator } +
            Symbol.PrefixOperator.allCases.map { $0.operator } +
            Symbol.PostfixOperator.allCases.map { $0.operator } +
            Symbol.punctuators.flatMap { [$0.left, $0.right] }
        
        return symbols.flatMap {
            if let v = $0 as? any Symbol.Vary, let symbols = v.symbols as? [Symbol.Define] {
                return symbols
            } else {
                return [$0]
            }
        }
    }()
}

extension Censor.Symbol {
    enum Spacing: CustomStringConvertible, Hashable {
        case symm(Bool?)
        case asym(Bool?)
        case any
        case none

        var description: String {
            switch self {
            case .symm(let bool): "symm" + (bool == nil ? "" : "(\(bool!))")
            case .asym(let bool): "asym" + (bool == nil ? "" : "(\(bool!))")
            case .any: "any"
            case .none: "none"
            }
        }
    }
}

extension Censor.Symbol {
    protocol Vary: Operator {
        associatedtype SymbolType
        var symbols: [SymbolType] { get }
    }
    protocol Prefix: Define {}
    protocol Postfix: Define {}
    protocol Infix: Define {}
}

extension Censor.Symbol.Vary {
    var name: String { fatalError("Vary 不应当被直接调用") }
    var lexeme: String { fatalError("Vary 不应当被直接调用") }
    var spacing: Censor.Symbol.Spacing { fatalError("Vary 不应当被直接调用") }
    var precedence: Censor.Symbol.AnyPrecedence { fatalError("Vary 不应当被直接调用") }
    var aliasAs: [any Censor.Symbol.Define] { fatalError("Vary 不应当被直接调用") }
}

extension Censor.Symbol.Define {
    var allowRepeating: Bool { false }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lexeme == rhs.lexeme
    }
}

extension Censor.Symbol.Prefix {
    var spacing: Censor.Symbol.Spacing { .asym(true) }
}

extension Censor.Symbol.Postfix {
    var spacing: Censor.Symbol.Spacing { .asym(false) }
}

extension Censor.Symbol.Infix {
    var spacing: Censor.Symbol.Spacing { .symm(nil) }
}

func == (lhs: any Censor.Symbol.Define, rhs: any Censor.Symbol.Define) -> Bool {
    lhs.lexeme == rhs.lexeme && type(of: lhs) == type(of: rhs)
}
