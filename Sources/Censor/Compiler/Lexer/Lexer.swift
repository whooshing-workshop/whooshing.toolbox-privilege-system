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
            return .init(tokens: tokens, diagnostics: errors, source: source)
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
    
    func advance(times: Int = 1) -> Character {
        guard times > 0 else { preconditionFailure("至少消费一个字符") }
        
        var c: Character? = nil
        for _ in 0..<times {
            c = advance()
        }
        return c!
        
        func advance() -> Character {
            let c = source[indexCurrent]
            lastChar = c
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
    
    func reportError(_ message: String, start: Censor.Compiler.SourceLocation, kind: Censor.Compiler.Error.Kind = .lexical) {
        let errorRange = Censor.Compiler.SourceRange(start: start, end: currentLocation)
        
        let error = Censor.Compiler.Error(
            kind: kind,
            range: errorRange,
            message: message,
            snippet: nil
        )
        errors.append(error)
        
        if !atEnd { _ = advance() }
    }
}

private extension Censor.Compiler.Lexer {
    /// 判定一个字符是否属于“字面量/变量”范畴（用于匹配 ■ 和 □）
    func isLiteralAttribute(_ char: Character?) -> Bool {
        guard let c = char else { return false }
        // 字母、数字、下划线，以及闭合括号都被视为字面量属性的延续/结尾
        return c.isLetter || c.isNumber || c == "_" || c == ")" || c == "]" || c == "'"
    }

    /// 根据左侧上下文，获取 Trie 树的起始 Sign
    var leftContextSign: Character {
        let isPrevLit = tokens.last?.type is Literal
        let isPrevSpace = lastChar == " "
        
        if isPrevLit {
            return isPrevSpace ? TrieNode.Sign.all.rawValue     // □ (Lit && Space)
                               : TrieNode.Sign.literal.rawValue // ■ (Lit && !Space)
        } else {
            return isPrevSpace ? TrieNode.Sign.space.rawValue   // ○ (!Lit && Space)
                               : TrieNode.Sign.none.rawValue    // ● (!Lit && !Space)
        }
    }

    /// 根据右侧上下文（peek），获取 Trie 树的结束 Sign
    func rightContextSign(at matchLength: Int) -> Character {
        guard let nextChar = peek(at: matchLength) else { return TrieNode.Sign.space.rawValue }
        let isNextSpace = nextChar.isWhitespace
        var isNextLit: Bool = false
        if isNextSpace {
            var i = matchLength + 1
            while let c = peek(at: i) {
                if !c.isWhitespace {
                    isNextLit = isLiteralAttribute(c)
                    break
                }
                i += 1
            }
        } else {
            isNextLit = isLiteralAttribute(nextChar)
        }
        
        if isNextLit {
            return isNextSpace ? TrieNode.Sign.all.rawValue     // □
                               : TrieNode.Sign.literal.rawValue // ■
        } else {
            return isNextSpace ? TrieNode.Sign.space.rawValue   // ○
                               : TrieNode.Sign.none.rawValue    // ●
        }
    }
}

private extension Censor.Compiler.Lexer {
    func scanToken() {
        guard let char = peek(at: 0) else { return }
        guard !char.isWhitespace else { _ = advance(); return }
        guard !scanSymbol() else { return }
        guard !scanLiteral() else { return }
        
        reportError("非预期的字符: \(char)", start: currentLocation)
        add(token: Extra.invalid, lexeme: String(char))
    }
    
    func scanSymbol() -> Bool {
        // 1. 根据左侧物理环境（是否是字面量、是否有空格）选择 Trie 的第一层入口
        guard var currentNode = TrieNode.root.children[leftContextSign] else {
            return false
        }
//        print(current, leftContextSign)
        var matchLength = 0
        var bestMatch: (symbol: Censor.Compiler.TrieSymbol, length: Int)? = nil
        
        // 2. 深度探测符号内容
        while let currentChar = peek(at: matchLength),
              let nextNode = currentNode.children[currentChar] {
            
            currentNode = nextNode
            matchLength += 1
            
            // 3. 核心：每前进一个字符，都探测其“后置约束”是否满足
            // 比如符号后是一个数字且无空格，则对应的 Sign 是 ■ (Literal && !Space)
            let sign = rightContextSign(at: matchLength)
//            print(current, matchLength + current, sign)
            
            if let found = currentNode.children[sign]?.symbol {
                // 贪婪匹配：记录当前最长路径
                bestMatch = (found, matchLength)
            }
        }
        
        // 4. 提交结果
        if let result = bestMatch {
            _ = advance(times: result.length)
            add(token: result.symbol.symbol, lexeme: result.symbol.lexeme)
            return true
        }
        
        return false
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
        let startLocation = currentLocation
        _ = advance()
        var value = ""
        
        // 只要没到结尾且没看到闭合引号，就一直走
        while !atEnd && peek(at: 0) != "\"" {
            let char = advance()
            
            if char == "\\" {
                guard !atEnd else { break }
                let escaped = advance()
                switch escaped {
                case "n": value.append("\n")
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                default: reportError("无效的转义序列: \\\(escaped)", start: currentLocation)
                }
            } else {
                value.append(char)
            }
        }
        
        // 退出循环后，检查是否是因为遇到了闭合引号
        guard !atEnd else {
            reportError("未闭合的字符串字面量", start: startLocation)
            // 这里不需要 addToken，因为是不完整的
            return true
        }
        
        // 消费掉最后的闭合引号
        _ = advance()
        
        add(token: Literal.string(Censor.StringType(nullable: false).make(value)), lexeme: "\"\(value)\"")
        return true
    }
    
    func scanSingleQuoteLiteral() -> Bool {
        let startLocation = currentLocation
        _ = advance() // 消费 '
        var content = ""
        while !atEnd && peek(at: 0) != "'" {
            content.append(advance())
        }
        
        guard !atEnd else {
            reportError("未闭合的单引号字面量", start: startLocation)
            return true
        }

        if content.count == 1 {
            add(token: Literal.character(Censor.CharacterType(nullable: false).make(content.first!)), lexeme: "'\(content)'")
        } else {
            guard let date = Censor.DateType.dateFormatter.date(from: content) else {
                reportError("日期格式错误，请遵循 ISO8601 日期格式，如 '2025-01-25T09:30:00Z'", start: startLocation)
                return true
            }
            add(token: Literal.date(Censor.DateType(nullable: false).make(date)), lexeme: "'\(content)'")
        }
        
        _ = advance() // 消费结尾 '
        return true
    }
    
    func scanNumber() -> Bool {
        let startLocation = currentLocation
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
                reportError("小数识别失败，格式有误", start: startLocation)
                return true
            }
            
            add(token: Literal.decimal(Censor.DecimalType(nullable: false).make(decimal)), lexeme: lexeme)
        } else {
            guard let num = Int64(lexeme) else {
                reportError("整数识别失败，格式有误", start: startLocation)
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
            add(token: Literal.identifier(lexeme), lexeme: lexeme)
        }
        
        return true
    }
}

extension Censor.Compiler.Lexer {
    struct Result {
        let tokens: [Censor.Compiler.Token]
        let diagnostics: [Censor.Compiler.Error]
        let source: String
        
        /// 是否存在足以中断编译的严重错误
        var hasErrors: Bool {
            !diagnostics.isEmpty
        }
    }
}
