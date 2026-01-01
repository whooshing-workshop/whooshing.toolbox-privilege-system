import Foundation

extension Censor {
    enum Keyword: String {
        case null           = "nil"
        case `in`           = "IN"
        case boolTrue       = "true"
        case boolFalse      = "false"
        
        var token: Compiler.Token.TokenType {
            switch self {
            case .null: Compiler.Token.Extra.null
            case .in: Compiler.Token.Extra.scope
            case .boolTrue: Compiler.Token.Literal.bool(BoolType(nullable: false).make(true))
            case .boolFalse: Compiler.Token.Literal.bool(BoolType(nullable: false).make(false))
            }
        }
    }
}

extension Censor.Compiler {
    enum BracketDirection {
        case left, right
    }
    
    enum BracketType: String, CustomStringConvertible {
        case parenth = "PAREN"
        case square = "SQUARE"
        
        var description: String { self.rawValue }
    }
    
    enum TernaryPart: String, CustomStringConvertible {
        case question = "QUEST"
        case colon = "COLON"
        
        var description: String { self.rawValue }
    }
    
    struct SourceLocation: Sendable, Equatable {
        let offset: Int /// 全局字符偏移量（从 0 开始），用于在原始 String 中快速切片
        let line: Int   /// 行号（通常从 1 开始计数）
        let column: Int /// 列号（通常从 1 开始计数）
        let sourceId: String? = nil
    }
    
    struct SourceRange: Sendable, Equatable {
        let start: SourceLocation
        let end: SourceLocation
    }
    
    struct Token {
        protocol TokenType: Sendable {}
        
        enum Literal: TokenType {
            case string(Censor.Variable<Censor.StringType>)
            case character(Censor.Variable<Censor.CharacterType>)
            case integer(Censor.Variable<Censor.IntegerType>)
            case decimal(Censor.Variable<Censor.DecimalType>)
            case date(Censor.Variable<Censor.DateType>)
            case uuid(Censor.Variable<Censor.UUIDType>)
            case bool(Censor.Variable<Censor.BoolType>)
            case trueType(Censor.Variable<Censor.TrueType>)
            case identifier(String)
        }
        
        enum Symbol: TokenType {
            case bracket(BracketType, BracketDirection)
            case prefixOperator(Censor.Operator.Prefix)
            case postfixOperator(Censor.Operator.Postfix)
            case infixOperator(Censor.Operator.Infix)
            case ternary(TernaryPart)
            case not
            case forceCast
            case nilCoalescing
            case dot
            case comma
            
            static var lexemeMap: [TrieSymbol] {
                [
                    TrieSymbol("(", .bracket(.parenth, .left), .prefix, spacing: .allow(symm: false)),
                    TrieSymbol(")", .bracket(.parenth, .right), .postfix, spacing: .allow(symm: false)),
                    TrieSymbol("[", .bracket(.square, .left), .prefix, spacing: .allow(symm: false)),
                    TrieSymbol("]", .bracket(.square, .right), .postfix, spacing: .allow(symm: false))
                ] + Censor.Operator.Prefix.allCases.map {
                    TrieSymbol($0.rawValue, Self.prefixOperator($0), .prefix, spacing: .no)
                } + Censor.Operator.Postfix.allCases.map {
                    TrieSymbol($0.rawValue, Self.postfixOperator($0), .postfix, spacing: .no)
                } + Censor.Operator.Infix.allCases.map {
                    TrieSymbol($0.rawValue, Self.infixOperator($0), .infix, spacing: .allow(symm: true))
                } + [
                    TrieSymbol("?", .ternary(.question), .infix, spacing: .allow(symm: true)),
                    TrieSymbol(":", .ternary(.colon), .infix, spacing: .allow(symm: true)),
                ] + [
                    TrieSymbol("!", .not, .prefix, spacing: .no),
                    TrieSymbol("!", .forceCast, .postfix, spacing: .no),
                    TrieSymbol("??", .nilCoalescing, .postfix, spacing: .allow(symm: true)),
                    TrieSymbol(".", .dot, .infix, spacing: .allow(symm: false)),
                    TrieSymbol(",", .comma, .infix, spacing: .allow(symm: false))
                ]
            }
        }
        
        enum Extra: TokenType {
            case scope
            case eof
            case invalid
            case null
        }
        
        let type: TokenType
        let lexeme: String
        let location: SourceLocation
    }
}
