import Foundation

extension Censor.Compiler {
    class Lexer {
        private let source: String
        private var tokens: [Token] = []
        
        private var start = 0               // 当前正在扫描的 Token 的起点
        private var current = 0             // 当前扫描到的位置
        private var indexStart: String.Index
        private var indexCurrent: String.Index
        private var line = 1                // 行号追踪
        private var column = 1              // 列号追踪
        private var lastChar: Character? = nil
        private var currentLocation: Censor.Compiler.SourceLocation {
            .init(offset: start, line: line, column: column)
        }
        
        var errors: [Censor.Compiler.Error] = []

        init(source: String) {
            self.source = source
            self.indexStart = source.startIndex
            self.indexCurrent = indexStart
        }
        
        func scanTokens() -> Result {
            while !atEnd {
                start = current
                scanToken()
            }
            
            add(token: Token.Extra.eof, lexeme: "")
            return .init(tokens: tokens, diagnostics: errors)
        }
    }
}

private extension Censor.Compiler.Lexer {
    typealias TrieNode = Censor.Compiler.TrieNode
    typealias Token = Censor.Compiler.Token
    typealias Literal = Token.Literal
    typealias Extra = Token.Extra
}

private extension Censor.Compiler.Lexer {
    var atEnd: Bool {
        indexCurrent == source.endIndex
    }
    
    var previousSpaceSign: Character {
        guard let last = lastChar else { return TrieNode.N }
        return last == " " ? TrieNode.S : TrieNode.N
    }
    
    func advance(times: Int = 1) -> Character {
        guard times > 0 else { preconditionFailure("至少消费一个字符") }
        
        var c: Character? = nil
        for _ in 0..<times {
            c = advance()
        }
        return c!
        
        func advance() -> Character {
            lastChar = current == 0 ? nil : source[source.index(before: indexCurrent)]
            let c = source[indexCurrent]
            indexCurrent = source.index(after: indexCurrent)
            current += 1
            
            if c == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            
            return c
        }
    }
    
    func add(token: Censor.Compiler.Token.TokenType, lexeme: String) {
        tokens.append(.init(type: token, lexeme: lexeme, location: currentLocation))
    }
    
    func peek(at offset: Int) -> Character? {
        guard
            let targetIndex = source.index(indexCurrent, offsetBy: offset, limitedBy: source.endIndex),
              targetIndex < source.endIndex
        else {
            return nil
        }
        return source[targetIndex]
    }
    
    func reportError(_ message: String, kind: Censor.Compiler.Error.Kind = .lexical) {
        let endLocation = currentLocation
        let errorRange = Censor.Compiler.SourceRange(start: currentLocation, end: endLocation)
        
        let error = Censor.Compiler.Error(
            kind: kind,
            range: errorRange,
            message: message,
            snippet: nil
        )
        errors.append(error)
    }
}

private extension Censor.Compiler.Lexer {
    func scanToken() {
        guard let char = peek(at: 0) else { return }
        guard !char.isWhitespace else { _ = advance(); return }
        guard !scanSymbol() else { return }
        guard !scanLiteral() else { return }
        
        reportError("非预期的字符: \(char)")
        let c = advance()
        add(token: Extra.invalid, lexeme: String(c))
    }
    
    func scanSymbol() -> Bool {
        // 1. 根据左侧上下文选择 Trie 分支
        guard var currentNode = TrieNode.root.children[previousSpaceSign] else {
            return false
        }
        
        var matchLength = 0
        var bestMatch: (symbol: Censor.Compiler.TrieSymbol, length: Int)? = nil
        
        // 2. 深度探测符号字符
        // 注意：matchLength 为 0 时 peek(at: 0) 是符号第一个字符
        while
            let currentChar = peek(at: matchLength),
            let nextNode = currentNode.children[currentChar]
        {
            
            currentNode = nextNode
            matchLength += 1
            
            // 3. 每走一步，都尝试匹配后续的“右侧空格上下文”
            // 探测：“在当前这个空格语境下，这个符号路径是否已经到头了？”
            let nextChar = peek(at: matchLength)
            let nextSign: Character = (nextChar?.isWhitespace ?? true) ? TrieNode.S : TrieNode.N
            
            // 注意：这里用 if let 而不是 guard
            // 即使当前节点不是终点，我们也要继续往后看，因为更长的符号可能在后面
            if let found = currentNode.children[nextSign]?.symbol {
                // 记录当前最长的合法匹配
                bestMatch = (found, matchLength)
            }
        }
        
        // 4. 提交匹配结果
        guard let result = bestMatch else { return false }
        
        _ = advance(times: result.length)
        add(token: result.symbol.symbol, lexeme: result.symbol.lexeme)
        return true
    }
    
    func scanLiteral() -> Bool {
        guard let char = peek(at: 0) else { return false }
        
        // 1. String: "XXX"
        if char == "\"" { return scanString() }
        
        // 2. Character or Date: 'x' or '2025-01-25...'
        if char == "'" { return scanSingleQuoteLiteral() }
        
        // 3. Number: 123 or 123.3
        if char.isNumber { return scanNumber() }
        
        // 4. Bool & Keywords: true, false
        if char.isLetter || char == "_" { return scanIdentifier() }
        
        return false
    }
}

private extension Censor.Compiler.Lexer {
    func scanString() -> Bool {
        // 1. 此时主指针 indexCurrent 在第一个 "
        _ = advance()
        var value = ""
        
        var closed = false
        // 2. 只要没到结尾且没看到闭合引号，就一直走
        while !atEnd {
            guard peek(at: 0) != "\"" else { closed = true; break; }
            
            let char = advance()
            
            if char == "\\" {
                guard !atEnd else { break }
                let escaped = advance()
                switch escaped {
                case "n": value.append("\n")
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                default: reportError("无效的转义序列: \\\(escaped)")
                }
            } else {
                value.append(char)
            }
        }
        
        // 3. 退出循环后，检查是否是因为遇到了闭合引号
        guard closed else {
            reportError("未闭合的字符串字面量")
            // 这里不需要 addToken，因为是不完整的
            return true
        }
        
        // 4. 消费掉最后的闭合引号
        _ = advance()
        
        // 5. 添加 Token。注意：lexeme 建议保留原始引号以供调试
        add(token: Literal.string(Censor.StringType(nullable: false).make(value)), lexeme: "\"\(value)\"")
        return true
    }
    
    func scanSingleQuoteLiteral() -> Bool {
        _ = advance() // 消费 '
        var content = ""
        while !atEnd && peek(at: 0) != "'" {
            content.append(advance())
        }
        
        guard !atEnd else {
            reportError("未闭合的单引号字面量")
            return true
        }
        _ = advance() // 消费结尾 '

        if content.count == 1 {
            add(token: Literal.character(Censor.CharacterType(nullable: false).make(content.first!)), lexeme: "'\(content)'")
        } else {
            guard let date = Censor.DateType.dateFormatter.date(from: content) else {
                reportError("日期格式错误，请遵循 ISO8601 日期格式，如 \"2025-01-25T09:33\"")
                return true
            }
            add(token: Literal.date(Censor.DateType(nullable: false).make(date)), lexeme: "'\(content)'")
        }
        return true
    }
    
    func scanNumber() -> Bool {
        let startIndex = indexCurrent
        var hasDecimal = false
        
        while let c = peek(at: 0), c.isNumber {
            _ = advance()
        }
        
        // 探测小数点：点后面必须跟着数字才是小数点，否则可能是成员访问（如 123.toString()）
        if let c = peek(at: 0), c == ".", let next = peek(at: 1), next.isNumber {
            hasDecimal = true
            _ = advance() // 消费 '.'
            while let nc = peek(at: 0), nc.isNumber {
                _ = advance()
            }
        }
        
        let lexeme = String(source[startIndex..<indexCurrent])
        if hasDecimal {
            guard let decimal = Decimal(string: lexeme) else {
                reportError("小数识别失败，格式有误")
                return true
            }
            
            add(token: Literal.decimal(Censor.DecimalType(nullable: false).make(decimal)), lexeme: lexeme)
        } else {
            guard let num = Int64(lexeme) else {
                reportError("整数识别失败，格式有误")
                return true
            }
            
            add(token: Literal.integer(Censor.IntegerType(nullable: false).make(num)), lexeme: lexeme)
        }
        return true
    }
    
    func scanIdentifier() -> Bool {
        let startIndex = indexCurrent
        
        // 1. 贪婪匹配：首位之后可以是字母、数字或下划线
        while let c = peek(at: 0), c.isLetter || c.isNumber || c == "_" {
            _ = advance()
        }
        
        // 2. 截取原始文本
        let lexeme = String(source[startIndex..<indexCurrent])
        
        // 3. 关键字检查 (Keyword Lookup)
        // 检查这个 lexeme 是否在 Keyword Map 中
        if let keywordType = Censor.Keyword(rawValue: lexeme)?.token {
            add(token: keywordType, lexeme: lexeme)
        } else {
            // 否则，它就是一个标识符
            add(token: Extra.identifier(lexeme), lexeme: lexeme)
        }
        
        return true
    }
}

extension Censor.Compiler.Lexer {
    struct Result {
        let tokens: [Censor.Compiler.Token]
        let diagnostics: [Censor.Compiler.Error]
        
        /// 是否存在足以中断编译的严重错误
        var hasErrors: Bool {
            !diagnostics.isEmpty
        }
    }
}
