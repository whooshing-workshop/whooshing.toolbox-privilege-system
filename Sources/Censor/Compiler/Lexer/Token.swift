import Foundation

extension Censor {
    enum Keyword: String {
        case null           = "nil"
        case `in`           = "IN"
        case boolTrue       = "true"
        case boolFalse      = "false"
        
        var token: any Compiler.Token.TokenType {
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
        protocol TokenType: Sendable, Equatable {}
        
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
            case prefixOperator(Censor.Operator.Prefix)
            case postfixOperator(Censor.Operator.Postfix)
            case infixOperator(Censor.Operator.Infix)
            case ternary(TernaryPart)
            case not
            case forceCast
            case optionalChaining
            case nilCoalescing
            
            static let lexemeMap: [TrieSymbol] =
                Censor.Operator.Prefix.allCases.map {
                    TrieSymbol($0.rawValue, Self.prefixOperator($0), .prefix, spacing: .asym(true))
                } + Censor.Operator.Postfix.allCases.map {
                    TrieSymbol($0.rawValue, Self.postfixOperator($0), .postfix, spacing: .asym(false))
                } + Censor.Operator.Infix.allCases.map {
                    TrieSymbol($0.rawValue, Self.infixOperator($0), .infix, spacing: .symm(nil))
                } + [
                    TrieSymbol("?", Self.ternary(.question), .infix, spacing: .symm(true), allowRepeating: true),
                    TrieSymbol(":", Self.ternary(.colon), .infix, spacing: .symm(true))
                ] + [
                    TrieSymbol("!", Self.not, .prefix, spacing: .asym(true)),
                    TrieSymbol("!", Self.forceCast, .postfix, spacing: .asym(false), allowRepeating: true),
                    TrieSymbol("?", Self.optionalChaining, .postfix, spacing: .asym(false)),
                    TrieSymbol("??", Self.nilCoalescing, .postfix, spacing: .symm(nil))
                ]
        }
        
        enum Punctuator: TokenType {
            enum Direction {
                case left, right
            }
            
            case bracket(BracketType, Direction)
            
            static let lexemeMap: [TrieSymbol] = [
                TrieSymbol("(", Self.bracket(.parenth, .left), .prefix, spacing: .any),
                TrieSymbol(")", Self.bracket(.parenth, .right), .postfix, spacing: .any),
                TrieSymbol("[", Self.bracket(.square, .left), .prefix, spacing: .any),
                TrieSymbol("]", Self.bracket(.square, .right), .postfix, spacing: .any) 
            ]
            
            static func signs(of direction: Direction) -> [Character] {
                switch direction {
                case .left: ["(", "["]
                case .right: [")", "]"]
                }
            }
        }
        
        enum Delimiter: TokenType {
            case dot
            case comma
            
            static let lexemeMap: [TrieSymbol] = [
                TrieSymbol(".", Self.dot, .infix, spacing: .any),
                TrieSymbol(",", Self.comma, .infix, spacing: .any)
            ]
        }
        
        enum Extra: TokenType {
            case scope
            case eof
            case invalid
            case null
        }
        
        let type: any TokenType
        let lexeme: String
        let location: SourceLocation
    }
}

// MARK: - Logs
extension Censor.Compiler.Token.Literal {
    var name: String {
        switch self {
        case .string:               return "STRING"
        case .character:            return "CHAR"
        case .integer:              return "INT"
        case .decimal:              return "DECIMAL"
        case .date:                 return "DATE"
        case .uuid:                 return "UUID"
        case .bool:                 return "BOOL"
        case .trueType:             return "TRUETYPE"
        case .identifier(let s):    return "IDENT(\(s))"
        }
    }
}

extension Censor.Compiler.Token.Symbol {
    var name: String {
        switch self {
        case .prefixOperator(let op):   return op.description
        case .postfixOperator(let op):  return op.description
        case .infixOperator(let op):    return op.description
        case .ternary(let part):        return "TERNARY_\(part)"
            
        case .not:                  return "NOT"
        case .forceCast:            return "F_CAST"
        case .optionalChaining:     return "OP_CHAIN"
        case .nilCoalescing:        return "NIL_COAL"
        }
    }
}

extension Censor.Compiler.Token.Punctuator {
    var name: String {
        switch self {
        case .bracket(let type, let dir):
            let dirStr = dir == .left ? "L" : "R"
            return "\(type)_\(dirStr)"
        }
    }
}

extension Censor.Compiler.Token.Delimiter {
    var name: String {
        switch self {
        case .dot:           return "DOT"
        case .comma:         return "COMMA"
        }
    }
}

extension Censor.Compiler.Token.Extra {
    var name: String {
        switch self {
        case .scope:            return "SCOPE(IN)"
        case .eof:              return "EOF"
        case .invalid:          return "INVALID"
        case .null:             return "NULL"
        }
    }
}

extension Censor.Compiler.SourceLocation: CustomStringConvertible {
    public var description: String {
        let file = sourceId != nil ? "\(sourceId!):" : ""
        return "\(file)\(line):\(column)"
    }
}

extension Censor.Compiler.SourceRange: CustomStringConvertible {
    public var description: String {
        if start.line == end.line {
            // 同一行: 1:5-12 (第1行，第5到12列)
            return "\(start.description)-\(end.column)"
        } else {
            // 跨行: 1:5-2:10 (第1行第5列 到 第2行第10列)
            return "\(start.description)-\(end.description)"
        }
    }
}
