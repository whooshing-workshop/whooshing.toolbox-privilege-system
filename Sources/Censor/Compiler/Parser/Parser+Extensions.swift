import Foundation

extension Censor.Parser {
    
    // MARK: - Navigation
    
    var atEnd: Bool {
        peek().content is Censor.Extra && (peek().content as? Censor.Extra) == .eof
    }

    func peek(at distance: Int = 0) -> Token {
        guard current + distance < tokens.count else {
            return tokens.last!
        }
        return tokens[current + distance]
    }

    func previous() -> Token {
        tokens[current - 1]
    }

    @discardableResult
    func advance() -> Token {
        if !atEnd { current += 1 }
        return previous()
    }
    
    // MARK: - Matching & Checking

    func check(_ type: any Censor.TokenUnit) -> Bool {
        if atEnd { return false }
        // TokenUnit 因关联值导致相等性检查较复杂。
        // 我们通常依赖 `content` 的相等性，或使用专门的检查方式。
        // Token.TokenUnit 是一个协议。
        // 这里的实现策略是：
        // 暂时使用字符串描述比较或运行时类型检查。
        
        // 目前使用简单的描述比较：
        return peek().content.description == type.description
    }
    
    /// 检查当前 Token 是否匹配特定 lexeme（适用于静态符号）
    func check(lexeme: String) -> Bool {
        if atEnd { return false }
        return peek().lexeme == lexeme
    }
    
    /// 检查当前 Token 是否匹配特定类型（安全）
    func check<T: Censor.TokenUnit>(_ type: T.Type) -> Bool {
        if atEnd { return false }
        return peek().content is T
    }

    /// 检查并消费指定类型的 Token (Generic Type Safe)
    func match<T: Censor.TokenUnit>(_ type: T.Type) -> Bool {
        if check(type) {
            advance()
            return true
        }
        return false
    }

    /// 检查并消费指定类型的 Token (Legacy Instance Check)
    func match(_ type: any Censor.TokenUnit) -> Bool {
        if check(type) {
            advance()
            return true
        }
        return false
    }
    
    /// 检查并消费指定 lexeme
    func match(lexeme: String) -> Bool {
        if check(lexeme: lexeme) {
            advance()
            return true
        }
        return false
    }

    /// 强制消费指定类型的 Token，否则报错
    @discardableResult
    func consume(_ type: any Censor.TokenUnit, message: String) -> Token? {
        if check(type) {
            return advance()
        }
        diagnostics.append(.init(kind: .syntactic, range: peek().range, message: message, snippet: nil))
        return nil
    }
    
    /// 强制消费指定类型的 Token (Generic Type Safe)
    @discardableResult
    func consume<T: Censor.TokenUnit>(_ type: T.Type, message: String) -> Token? {
        if check(type) {
            return advance()
        }
        diagnostics.append(.init(kind: .syntactic, range: peek().range, message: message, snippet: nil))
        return nil
    }

    /// 消费特定 lexeme
    @discardableResult
    func consume(lexeme: String, message: String) -> Token? {
        if check(lexeme: lexeme) {
            return advance()
        }
        diagnostics.append(.init(kind: .syntactic, range: peek().range, message: message, snippet: nil))
        return nil
    }
    
    /// 消费 Identifier（辅助方法）
    func consumeIdentifier(message: String) -> Token? {
        if case .identifier = peek().content as? Censor.Literal {
            return advance()
        }
        report(error: message)
        return nil
    }
    
    // MARK: - Error Handling
    
    /// 报告语法错误（使用当前 Token 位置）
    func report(error message: String) {
        diagnostics.append(.init(kind: .syntactic, range: peek().range, message: message, snippet: nil))
    }
    
    /// 报告语法错误（指定位置）
    func report(error message: String, at token: Token) {
        diagnostics.append(.init(kind: .syntactic, range: token.range, message: message, snippet: nil))
    }
    
    /// 报告语法错误（指定范围）
    func report(error message: String, range: Censor.SourceRange) {
        diagnostics.append(.init(kind: .syntactic, range: range, message: message, snippet: nil))
    }
    
    func synchronize() {
        advance()
        while !atEnd {
            advance()
        }
    }
}
