import Foundation

extension Censor.Compiler {
    class Parser {
        private let tokens: [Token]
        private var current = 0
        private var errors: [Censor.Compiler.Error] = []
        private let source: String

        init(tokens: [Token], source: String) {
            self.tokens = tokens
            self.source = source
        }

        typealias Token = Censor.Compiler.Token

        func parse() -> Result {
            var statements: [Censor.AST] = []

            while !atEnd {
                do {
                    let stmt = try parseExpression()
                    statements.append(stmt)
                } catch {
                    synchronize()
                }
            }

            return Result(ast: statements, diagnostics: errors, source: source)
        }
    }
}

// MARK: - Pratt Parsing Engine
extension Censor.Compiler.Parser {

    func parseExpression(precedence: Int = 0) throws -> Censor.AST {
        let token = advance()

        guard let prefixRule = getRule(token.type).prefix else {
            throw error(token: token, message: "Expect expression.")
        }

        var left = try prefixRule(token)

        while precedence < getPrecedence(peek.type) {
            let nextToken = advance()

            guard let infixRule = getRule(nextToken.type).infix else {
                throw error(token: nextToken, message: "Expect infix rule.")
            }

            left = try infixRule(left, nextToken)
        }

        return left
    }

    struct ParseRule {
        let prefix: ((Censor.Compiler.Token) throws -> Censor.AST)?
        let infix: ((Censor.AST, Censor.Compiler.Token) throws -> Censor.AST)?
        let precedence: Int

        init(
            prefix: ((Censor.Compiler.Token) throws -> Censor.AST)? = nil,
            infix: ((Censor.AST, Censor.Compiler.Token) throws -> Censor.AST)? = nil,
            precedence: Int = 0
        ) {
            self.prefix = prefix
            self.infix = infix
            self.precedence = precedence
        }
    }

    func getRule(_ type: any Token.TokenType) -> ParseRule {
        switch type {
        case let literal as Token.Literal:
            return ParseRule(prefix: { [weak self] _ in
                try self?.literal(literal)
                    ?? .value(Censor.AnyVariable(Censor.IntegerType(nullable: false).make(0)))
            })

        case Token.Punctuator.bracket(.parenth, .left):
            return ParseRule(
                prefix: grouping, infix: call, precedence: Censor.Operator.Precedence.Postfix.power)

        case Token.Punctuator.bracket(.square, .left):
            return ParseRule(
                prefix: arrayLiteral, infix: subscriptCall,
                precedence: Censor.Operator.Precedence.Postfix.power)

        case Token.Symbol.prefixOperator(let op):
            return ParseRule(prefix: unary, precedence: op.precedence.power)

        case Token.Symbol.infixOperator(let op):
            return ParseRule(infix: binary, precedence: op.precedence.power)

        case Token.Symbol.sugar(.ternary(.question)):
            return ParseRule(infix: ternary, precedence: Censor.Operator.Precedence.Ternary.power)

        case Token.Delimiter.dot:
            return ParseRule(infix: dot, precedence: Censor.Operator.Precedence.Postfix.power)

        case Token.Symbol.sugar(.not):
            return ParseRule(prefix: unary, precedence: Censor.Operator.Precedence.Prefix.power)

        default:
            return ParseRule()
        }
    }

    func getPrecedence(_ type: any Token.TokenType) -> Int {
        getRule(type).precedence
    }
}

// MARK: - Parsing Functions
extension Censor.Compiler.Parser {

    // Prefix
    func literal(_ type: Token.Literal) throws -> Censor.AST {
        switch type {
        case .integer(let v): return .value(Censor.AnyVariable(v))
        case .decimal(let v): return .value(Censor.AnyVariable(v))
        case .string(let v): return .value(Censor.AnyVariable(v))
        case .bool(let v): return .value(Censor.AnyVariable(v))
        case .identifier(let s):
            return .variable(s)

        case .character, .date, .uuid, .trueType:
            throw error(
                token: previous,
                message: "Literal type \(type) not fully supported in AST construction yet.")
        }
    }

    func grouping(_ token: Token) throws -> Censor.AST {
        let expr = try parseExpression()
        try consume(
            Token.Punctuator.bracket(.parenth, .right), message: "Expect ')' after expression.")
        return expr
    }

    func unary(_ token: Token) throws -> Censor.AST {
        guard let symbol = token.type as? Token.Symbol else {
            throw error(token: token, message: "Invalid unary operator.")
        }

        let rule = getRule(token.type)
        let right = try parseExpression(precedence: rule.precedence)

        switch symbol {
        case .prefixOperator(let op):
            return .prefix(operator: op, right: right)
        case .sugar(.not):
            return .function("!", args: [right])
        default:
            throw error(token: token, message: "Unexpected unary operator.")
        }
    }

    func arrayLiteral(_ token: Token) throws -> Censor.AST {
        var elements: [Censor.AST] = []
        if !check(Token.Punctuator.bracket(.square, .right)) {
            repeat {
                if check(Token.Punctuator.bracket(.square, .right)) { break }
                elements.append(try parseExpression())
            } while match(Token.Delimiter.comma)
        }
        try consume(
            Token.Punctuator.bracket(.square, .right), message: "Expect ']' after array elements.")
        return .array(elements)
    }

    // Infix
    func binary(_ left: Censor.AST, _ token: Token) throws -> Censor.AST {
        guard let symbol = token.type as? Token.Symbol,
            case .infixOperator(let op) = symbol
        else {
            throw error(token: token, message: "Invalid binary operator.")
        }

        let rule = getRule(token.type)
        var precedence = rule.precedence

        if op.precedence.associative == .right {
            precedence -= 1
        }

        let right = try parseExpression(precedence: precedence)
        return .infix(operator: op, left: left, right: right)
    }

    func call(_ left: Censor.AST, _ token: Token) throws -> Censor.AST {
        var args: [Censor.AST] = []
        if !check(Token.Punctuator.bracket(.parenth, .right)) {
            repeat {
                if check(Token.Punctuator.bracket(.parenth, .right)) { break }
                args.append(try parseExpression())
            } while match(Token.Delimiter.comma)
        }
        try consume(
            Token.Punctuator.bracket(.parenth, .right), message: "Expect ')' after arguments.")

        switch left {
        case .variable(let name):
            return .function(name, args: args)
        case .property(let name):
            return .function(name, args: args)
        default:
            throw error(token: previous, message: "Expected function name before '('.")
        }
    }

    func subscriptCall(_ left: Censor.AST, _ token: Token) throws -> Censor.AST {
        let inner = try parseExpression()
        try consume(Token.Punctuator.bracket(.square, .right), message: "Expect ']' after index.")

        if case .value(let v) = inner, case .integer(let i) = v.storingValue, let idx = i {
            return .chain(content: left, next: .arraySelector(index: Int(idx)))
        } else {
            throw error(token: token, message: "Array index must be an integer literal.")
        }
    }

    func ternary(_ left: Censor.AST, _ token: Token) throws -> Censor.AST {
        let trueExpr = try parseExpression()
        try consume(Token.Symbol.sugar(.ternary(.colon)), message: "Expect ':' in ternary.")
        let falseExpr = try parseExpression()

        return .ternary(condition: left, pass: trueExpr, fail: falseExpr)
    }

    func dot(_ left: Censor.AST, _ token: Token) throws -> Censor.AST {
        let name = try consumeIdentifier()
        return .chain(content: left, next: .property(name))
    }
}

// MARK: - Helpers
extension Censor.Compiler.Parser {

    var atEnd: Bool {
        return peek.type == Token.Extra.eof
    }

    var peek: Token {
        return tokens[current]
    }

    var previous: Token {
        return tokens[current - 1]
    }

    @discardableResult
    func advance() -> Token {
        if !atEnd { current += 1 }
        return previous
    }

    @discardableResult
    func consume(_ type: any Token.TokenType, message: String) throws -> Token {
        if check(type) {
            return advance()
        }
        throw error(token: peek, message: message)
    }

    func consumeIdentifier() throws -> String {
        if case Token.Literal.identifier(let s) = peek.type {
            advance()
            return s
        }
        throw error(token: peek, message: "Expect identifier.")
    }

    func check(_ type: any Token.TokenType) -> Bool {
        if atEnd { return false }
        return peek.type == type
    }

    func match(_ type: any Token.TokenType) -> Bool {
        if check(type) {
            advance()
            return true
        }
        return false
    }

    func error(token: Token, message: String) -> Censor.Compiler.Error {
        let err = Censor.Compiler.Error(
            kind: .syntactic,
            range: token.range,
            message: message,
            snippet: nil
        )
        errors.append(err)
        return err
    }

    func synchronize() {
        advance()
        while !atEnd {
            if previous.type == Token.Delimiter.comma { return }
            advance()
        }
    }
}

// MARK: - Result Validation
extension Censor.Compiler.Parser {
    public struct Result {
        public let ast: [Censor.AST]
        public let diagnostics: [Censor.Compiler.Error]
        public let source: String

        public var hasErrors: Bool { !diagnostics.isEmpty }
    }
}
