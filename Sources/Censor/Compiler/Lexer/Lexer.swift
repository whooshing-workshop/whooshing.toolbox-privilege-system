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
        private var lastSymbol: TrieSymbol? = nil
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
            
            add(token: Token.Extra.eof, start: currentLocation, lexeme: " ")
            return Result(tokens: tokens, diagnostics: errors, source: source)
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
    
    @discardableResult
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
    
    func peek(at offset: Int) -> Character? {
        guard
            let targetIndex = source.index(indexCurrent, offsetBy: offset, limitedBy: source.endIndex),
              targetIndex < source.endIndex
        else {
            return nil
        }
        return source[targetIndex]
    }
    
    func add(token: any Censor.Compiler.Token.TokenType, start: Censor.Compiler.SourceLocation, lexeme: String) {
        tokens.append(.init(type: token, lexeme: lexeme, range: .init(start: start, end: start.offset(by: lexeme.count - 1))))
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
    /// 根据左侧上下文，获取 Trie 树的起始 Sign
    var leftContextSign: Character {
        guard let c = lastChar else { return TrieNode.S }
        
        if let lastToken = lastSymbol, let c = lastChar, lastToken.allowRepeating, !c.isWhitespace, c != "\"" {
            switch lastToken.spacing {
            case .symm(let bool):
                if let b = bool {
                    return b ? TrieNode.S : TrieNode.N
                }
            case .asym(let bool):
                if let b = bool {
                    return b ? TrieNode.S : TrieNode.N
                }
            case .any: return TrieNode.N
            case .none: return TrieNode.N
            }
        }
        
        if (
            Token.Punctuator.signs(of: .left) +
            Token.Delimiter.lexemeMap.map { $0.lexeme.first! }
        ).contains(where: { $0 == c }) || c.isWhitespace || c == "\n" || c == "\t" {
            return TrieNode.S
        } else {
            return TrieNode.N
        }
    }

    /// 根据右侧上下文（peek），获取 Trie 树的结束 Sign
    func rightContextSign(at matchLength: Int) -> Character {
        guard let c = peek(at: matchLength) else { return TrieNode.S }
        
        if (
            Token.Punctuator.signs(of: .right) +
            Token.Delimiter.lexemeMap.map { $0.lexeme.first! }
        ).contains(where: { $0 == c }) || c.isWhitespace || c == "\n" || c == "\t" {
            return TrieNode.S
        } else {
            return TrieNode.N
        }
    }
    
    func isNextSymbolMatched(at matchLength: Int, lexeme: String) -> Bool {
        var match = true
        for (i, c) in lexeme.enumerated() {
            guard let n = peek(at: matchLength + i) else {
                break
            }
            if c != n {
                match = false
                break
            }
        }
        return match
    }
}

private extension Censor.Compiler.Lexer {
    func scanToken() {
        guard let char = peek(at: 0) else { return }
        guard !char.isWhitespace else { _ = advance(); return }
        guard !scanSymbol() else { return }
        lastSymbol = nil
        guard !scanLiteral() else { return }
        
        add(token: Extra.invalid, start: currentLocation, lexeme: String(char))
        reportError("非预期的字符: \(char)", start: currentLocation)
    }
    
    func scanSymbol() -> Bool {
        // 1. 根据左侧物理环境（是否是字面量、是否有空格）选择 Trie 的第一层入口
        guard var currentNode = TrieNode.root.children[leftContextSign] else {
            return false
        }
        
        var matchLength = 0
        var bestMatch: (symbol: Censor.Compiler.TrieSymbol, length: Int)? = nil
        var matchedLexeme = ""
        // 2. 深度探测符号内容
        while let currentChar = peek(at: matchLength),
              let nextNode = currentNode.children[currentChar] {
            
            currentNode = nextNode
            matchLength += 1
            matchedLexeme += String(currentChar)
            // 3. 核心：每前进一个字符，都探测其“后置约束”是否满足
            // 比如符号后是一个数字且无空格，则对应的 Sign 是 ■ (Literal && !Space)
            let sign = rightContextSign(at: matchLength)
            if let found = currentNode.children[sign]?.symbol {
                // 贪婪匹配：记录当前最长路径
                bestMatch = (found, matchLength)
            } else {
                for (_, node) in currentNode.children {
                    guard node.isLeaf, let s = node.symbol, s.allowRepeating else { continue }
                    if isNextSymbolMatched(at: matchLength, lexeme: matchedLexeme) {
                        bestMatch = (s, matchLength)
                        break
                    }
                }
            }
        }
        
        // 4. 提交结果
        if let result = bestMatch {
            lastSymbol = result.symbol
            let start = currentLocation
            advance(times: result.length)
            add(token: result.symbol.symbol, start: start, lexeme: result.symbol.lexeme)
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
        
        add(token: Literal.string(Censor.StringType(nullable: false).make(value)), start: startLocation, lexeme: "\"\(value)\"")
        
        // 消费掉最后的闭合引号
        _ = advance()
        
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
            add(token: Literal.character(Censor.CharacterType(nullable: false).make(content.first!)), start: startLocation, lexeme: "'\(content)'")
        } else {
            guard let date = Censor.DateType.dateFormatter.date(from: content) else {
                reportError("日期格式错误，请遵循 ISO8601 日期格式，如 '2025-01-25T09:30:00Z'", start: startLocation)
                return true
            }
            add(token: Literal.date(Censor.DateType(nullable: false).make(date)), start: startLocation, lexeme: "'\(content)'")
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
            
            add(token: Literal.decimal(Censor.DecimalType(nullable: false).make(decimal)), start: startLocation, lexeme: lexeme)
        } else {
            guard let num = Int64(lexeme) else {
                reportError("整数识别失败，格式有误", start: startLocation)
                return true
            }
            
            add(token: Literal.integer(Censor.IntegerType(nullable: false).make(num)), start: startLocation, lexeme: lexeme)
        }
        return true
    }
    
    func scanIdentifier() -> Bool {
        let startIndex = indexCurrent
        let startLocation = currentLocation
        
        // 1. 贪婪匹配：首位之后可以是字母、数字或下划线
        while let c = peek(at: 0), c.isLetter || c.isNumber || c == "_" {
            _ = advance()
        }
        
        // 2. 截取原始文本
        let lexeme = String(source[startIndex..<indexCurrent])
        
        // 3. 关键字检查 (Keyword Lookup)
        // 检查这个 lexeme 是否在 Keyword Map 中
        if let keywordType = Censor.Keyword(rawValue: lexeme)?.token {
            add(token: keywordType, start: startLocation, lexeme: lexeme)
        } else {
            // 否则，它就是一个标识符
            add(token: Literal.identifier(lexeme), start: startLocation, lexeme: lexeme)
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

// MARK: - Logs
extension Censor.Compiler.Lexer.Result: CustomStringConvertible {
    var description: String {
        guard !tokens.isEmpty || !diagnostics.isEmpty else { return "词法分析: 空输入" }

        if hasErrors {
            return formatErrorReport()
        } else {
            return formatTokenList()
        }
    }

    private func formatTokenList() -> String {
        let maxPreview = 100
        let previewTokens = Array(tokens.prefix(maxPreview))
        
        // 1. 预计算每一列的最大宽度
        var maxPosWidth = "Location".count // 预留表头宽度
        var maxTypeWidth = "Type".count
        var maxLexemeWidth = "Lexeme".count

        for token in previewTokens {
            let posStr = "[\(token.range)]"
            let typeStr = token.type.description
            let lexemeStr = "`\(token.lexeme.replacingOccurrences(of: "\n", with: "\\n"))`"
            
            maxPosWidth = max(maxPosWidth, posStr.count)
            maxTypeWidth = max(maxTypeWidth, typeStr.count)
            maxLexemeWidth = max(maxLexemeWidth, lexemeStr.count)
        }

        // 2. 计算总宽度：三列宽度 + 两个分隔符 (每个 "  │  " 占 5 个宽度) + 两端间距
        // 这里的 10 是：开头空1 + 间距1(2) + 间距2(2) + 间距3(2) + 结尾1 ...
        // 简单计算：空格 + 坐标 + 间距 + 类型 + 间距 + 源码 + 空格
        let paddingWidth = 8
        let totalWidth = maxPosWidth + maxTypeWidth + maxLexemeWidth + paddingWidth
        let bar = String(repeating: "━", count: totalWidth)
        let thinLine = String(repeating: "─", count: totalWidth)

        // 3. 构建输出
        var output = "\n" + "词法分析通过: \(tokens.count) TOKENS\n"
        output += bar + "\n"
        
        // 表头 (可选)
        let hPos = "Location".padding(toLength: maxPosWidth, withPad: " ", startingAt: 0)
        let hType = "Type".padding(toLength: maxTypeWidth, withPad: " ", startingAt: 0)
        output += " \(hPos) │ \(hType) │ Lexeme\n"
        output += thinLine + "\n"

        // 内容行
        for token in previewTokens {
            let pos = "[\(token.range)]".padding(toLength: maxPosWidth, withPad: " ", startingAt: 0)
            let typeName = token.type.description.padding(toLength: maxTypeWidth, withPad: " ", startingAt: 0)
            let cleanLexeme = "`\(token.lexeme.replacingOccurrences(of: "\n", with: "\\n"))`"
            
            output += " \(pos) │ \(typeName) │ \(cleanLexeme)\n"
        }

        if tokens.count > maxPreview {
            output += thinLine + "\n"
            output += " ... 还有 \(tokens.count - maxPreview) 个 tokens.\n"
        }
        
        output += bar + "\n"
        return output
    }

    private func formatErrorReport() -> String {
        let thickLine = String(repeating: "━", count: 60)
        let thinLine  = String(repeating: "─", count: 60)
        
        var output = "\n" + thickLine + "\n"
        output += " 词法分析失败, 找到 \(diagnostics.count) 个错误\n"
        output += thickLine + "\n"
        
        for (index, error) in diagnostics.enumerated() {
            if index > 0 { output += thinLine + "\n" }
            output += " [错误 \(index + 1)]\n"
            output += error.prettyDescription(in: source) + "\n"
        }
        
        output += thickLine + "\n"
        return output
    }
}
