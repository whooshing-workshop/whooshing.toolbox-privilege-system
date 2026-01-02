import Foundation

extension Censor {
    enum Keyword: String, Equatable, Censor.Compiler.Token.TokenType {
        case null           = "nil"
        case `in`           = "IN"
        case boolTrue       = "true"
        case boolFalse      = "false"
        
        var token: any Compiler.Token.TokenType {
            switch self {
            case .boolTrue: Compiler.Token.Literal.bool(BoolType(nullable: false).make(true))
            case .boolFalse: Compiler.Token.Literal.bool(BoolType(nullable: false).make(false))
            default: self
            }
        }
        
        var description: String {
            let keyw = switch self {
            case .null: "NULL"
            case .in: "IN"
            case .boolTrue, .boolFalse: fatalError()
            }
            return "Keyword." + keyw
        }
    }
}

extension Censor.Compiler {
    enum BracketType: String, CustomStringConvertible {
        case parenth = "PAREN"
        case square = "SQUARE"
        
        var description: String { self.rawValue }
    }
    
    struct SourceLocation: Sendable, Equatable {
        let offset: Int /// 全局字符偏移量（从 0 开始），用于在原始 String 中快速切片
        let line: Int   /// 行号（通常从 1 开始计数）
        let column: Int /// 列号（通常从 1 开始计数）
        let sourceId: String? = nil
        
        func offset(by i: Int) -> Self {
            .init(offset: offset, line: line, column: column + i)
        }
    }
    
    struct SourceRange: Sendable, Equatable {
        let start: SourceLocation
        let end: SourceLocation
    }
    
    struct Token {
        protocol TokenType: Sendable, Equatable, CustomStringConvertible {}
        
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
            case sugar(Censor.SugarKey)
            
            static let lexemeMap: [TrieSymbol] =
                Censor.Operator.Prefix.allCases.map {
                    TrieSymbol($0.rawValue, Self.prefixOperator($0), .prefix, spacing: .asym(true))
                } + Censor.Operator.Postfix.allCases.map {
                    TrieSymbol($0.rawValue, Self.postfixOperator($0), .postfix, spacing: .asym(false))
                } + Censor.Operator.Infix.allCases.map {
                    TrieSymbol($0.rawValue, Self.infixOperator($0), .infix, spacing: .symm(nil))
                } + Censor.SugarKey.allCases.flatMap { $0.sugar.lexemes }
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
            case colon
            case dot
            case comma
            
            static let lexemeMap: [TrieSymbol] = [
                TrieSymbol(":", Self.colon, .infix, spacing: .asym(false)),
                TrieSymbol(".", Self.dot, .infix, spacing: .any),
                TrieSymbol(",", Self.comma, .infix, spacing: .any)
            ]
        }
        
        enum Extra: TokenType {
            case eof
            case invalid
        }
        
        let type: any TokenType
        let lexeme: String
        let range: SourceRange
    }
}

func == (
    lhs: any Censor.Compiler.Token.TokenType,
    rhs: any Censor.Compiler.Token.TokenType
) -> Bool {
    lhs.description == rhs.description
}

// MARK: - Logs
extension Censor.Compiler.Token.Literal: CustomStringConvertible {
    var description: String {
        let lit = switch self {
        case .string:               "STRING"
        case .character:            "CHAR"
        case .integer:              "INT"
        case .decimal:              "DECIMAL"
        case .date:                 "DATE"
        case .uuid:                 "UUID"
        case .bool:                 "BOOL"
        case .trueType:             "TRUETYPE"
        case .identifier(let s):    "IDENT(\(s))"
        }
        return "Literal." + lit
    }
}

extension Censor.Compiler.Token.Symbol: CustomStringConvertible {
    var description: String {
        let sym = switch self {
        case .prefixOperator(let op):   op.description
        case .postfixOperator(let op):  op.description
        case .infixOperator(let op):    op.description
        case .sugar(let sugar):         sugar.description
        }
        return "Symbol." + sym
    }
}

extension Censor.Compiler.Token.Punctuator: CustomStringConvertible {
    var description: String {
        let punc: String
        switch self {
        case .bracket(let type, let dir):
            let dirStr = dir == .left ? "L" : "R"
            punc = "\(type)_\(dirStr)"
        }
        return "Punctuator." + punc
    }
}

extension Censor.Compiler.Token.Delimiter: CustomStringConvertible {
    var description: String {
        let del = switch self {
        case .colon:        "COLON"
        case .dot:          "DOT"
        case .comma:        "COMMA"
        }
        return "Delimiter." + del
    }
}

extension Censor.Compiler.Token.Extra: CustomStringConvertible {
    var description: String {
        switch self {
        case .eof:              return "EOF"
        case .invalid:          return "INVALID"
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
        if start == end {
            return start.description
        } else if start.line == end.line {
            // 同一行: 1:5-12 (第1行，第5到12列)
            return "\(start.description)-\(end.column)"
        } else {
            // 跨行: 1:5-2:10 (第1行第5列 到 第2行第10列)
            return "\(start.description)-\(end.description)"
        }
    }
}
