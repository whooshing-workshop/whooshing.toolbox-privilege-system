extension Censor.Compiler {
    enum SymbolType: String, Hashable, CustomStringConvertible {
        case prefix     = "Prefix"
        case postfix    = "Postfix"
        case infix      = "Infix"
        
        var description: String { self.rawValue }
    }
    
    struct TrieSymbol {
        let lexeme: String
        let symbol: Token.Symbol
        let symbolType: SymbolType
        let spacing: Spacing
        
        enum Spacing {
            case must(symm: Bool)
            case allow(symm: Bool)
            case no
        }
        
        init(
            _ lexeme: String,
            _ symbol: Token.Symbol,
            _ symbolType: SymbolType,
            spacing: Spacing
        ) {
            self.symbol = symbol
            self.lexeme = lexeme
            self.symbolType = symbolType
            self.spacing = spacing
        }
    }
    

    class TrieNode: @unchecked Sendable {
        private(set) var children: [Character: TrieNode] = [:]
        private(set) var symbol: TrieSymbol? = nil
        private(set) var isTail: Bool
        
        enum Sign: Character, Sendable {
            case all            = "□"
            case literal        = "■"
            case space          = "○"
            case none           = "●"
        }
        
        static let root = TrieNode.build(from: Token.Symbol.lexemeMap)
        
        var isLeaf: Bool { children.isEmpty }
        
        private init(children: [Character : TrieNode] = [:], symbol: TrieSymbol? = nil, isTail: Bool = false) {
            self.children = children
            self.symbol = symbol
            self.isTail = isTail
        }
        
        static func build(from symbols: [TrieSymbol]) -> TrieNode {
            let root = TrieNode()
            
            for trieSymbol in symbols {
                
                // 每个 Symbol 的前后空格以及位置均有严格规定，设定存于
                // TrieSymbol 的 spacing 以及 symbolType 中
                // 下面列出所有处理情况：
                //
                //   a □: 前一个字符必须为空格, 且必须为字面量/变量
                //   l ■: 前一个字符必须不是空格, 且必须为字面量/变量
                //   s ○: 前一个字符必须为空格, 且必须不为字面量/变量
                //   n ●: 前一个字符必须不是空格, 且必须不为字面量/变量
                //    <>: 符号的值，每个 TrieNode 仅存一个字母
                //
                //  ----------------------------------------------------
                //  |               |         在 Trie 树中的存储链
                //  |               |              一行表示一条
                //  |---------------|-----------------------------------
                //  |   .must(true) |   ○   | <> |   □   |  1  |  s a  |
                //  |       .prefix |       |    |       |     |       |
                //  |---------------|-------|----|-------|-----|-------|
                //  |  .must(false) |   ○   | <> |   □   |  3  |  s a  |
                //  |       .prefix |   ○   | <> |   ■   |     |  s l  |
                //  |               |   ●   | <> |   □   |     |  n a  |
                //  |---------------|-------|----|-------|-----|-------|
                //  |  .allow(true) |   ○   | <> |   □   |  2  |  s a  |
                //  |       .prefix |   ●   | <> |   ■   |     |  n l  |
                //  |---------------|-------|----|-------|-----|-------|
                //  | .allow(false) |   ●   | <> |   ■   |  4  |  n l  |
                //  |       .prefix |   ○   | <> |   ■   |     |  s l  |
                //  |               |   ○   | <> |   □   |     |  s a  |
                //  |               |   ●   | <> |   □   |     |  n a  |
                //  |---------------|-------|----|-------|-----|-------|
                //  |           .no |   ●   | <> |   ■   |  1  |  n l  |
                //  |       .prefix |       |    |       |     |       |
                //  ----------------------------------------------------
                //
                //  ----------------------------------------------------
                //  |   .must(true) |   □   | <> |   ○   |  1  |  a s  |
                //  |      .postfix |       |    |       |     |       |
                //  |---------------|-------|----|-------|-----|-------|
                //  |  .must(false) |   □   | <> |   ○   |  3  |  a s  |
                //  |      .postfix |   □   | <> |   ●   |     |  a n  |
                //  |               |   ■   | <> |   ○   |     |  l s  |
                //  |---------------|-------|----|-------|-----|-------|
                //  |  .allow(true) |   □   | <> |   ○   |  2  |  a s  |
                //  |      .postfix |   ■   | <> |   ●   |     |  l n  |
                //  |---------------|-------|----|-------|-----|-------|
                //  | .allow(false) |   ■   | <> |   ●   |  4  |  l n  |
                //  |      .postfix |   □   | <> |   ●   |     |  a n  |
                //  |               |   □   | <> |   ○   |     |  a s  |
                //  |               |   ■   | <> |   ○   |     |  l s  |
                //  |---------------|-------|----|-------|-----|-------|
                //  |           .no |   ■   | <> |   ●   |  1  |  l n  |
                //  |      .postfix |       |    |       |     |       |
                //  ----------------------------------------------------
                //
                //  ----------------------------------------------------
                //  |   .must(true) |   □   | <> |   □   |  1  |  a a  |
                //  |        .infix |       |    |       |     |       |
                //  |---------------|-------|----|-------|-----|-------|
                //  |  .must(false) |   □   | <> |   □   |  3  |  a a  |
                //  |        .infix |   □   | <> |   ■   |     |  a l  |
                //  |               |   ■   | <> |   □   |     |  l a  |
                //  |---------------|-------|----|-------|-----|-------|
                //  |  .allow(true) |   □   | <> |   □   |  2  |  a a  |
                //  |        .infix |   ■   | <> |   ■   |     |  l l  |
                //  |---------------|-------|----|-------|-----|-------|
                //  | .allow(false) |   ■   | <> |   ■   |  4  |  l l  |
                //  |        .infix |   □   | <> |   ■   |     |  a l  |
                //  |               |   □   | <> |   □   |     |  a a  |
                //  |               |   ■   | <> |   □   |     |  l a  |
                //  |---------------|-------|----|-------|-----|-------|
                //  |           .no |   ■   | <> |   ■   |  1  |  l l  |
                //  |        .infix |       |    |       |     |       |
                //  ----------------------------------------------------
                //
                let checkList: [(Sign, Sign)]
                let a = Sign.all                // □
                let l = Sign.literal            // ■
                let s = Sign.space              // ○
                let n = Sign.none               // ●
                switch trieSymbol.spacing {
                case .must(let symm):
                    switch trieSymbol.symbolType {
                    case .prefix:
                        checkList = symm ? [(s, a)] : [(s, a), (s, l), (n, a)]
                    case .postfix:
                        checkList = symm ? [(a, s)] : [(a, s), (a, n), (l, s)]
                    case .infix:
                        checkList = symm ? [(a, a)] : [(a, a), (a, l), (l, a)]
                    }
                case .allow(let symm):
                    switch trieSymbol.symbolType {
                    case .prefix:
                        checkList = symm ? [(s, a), (n, l)] : [(n, l), (s, l), (s, a), (n, a)]
                    case .postfix:
                        checkList = symm ? [(a, s), (l, n)] : [(l, n), (a, n), (a, s), (l, s)]
                    case .infix:
                        checkList = symm ? [(a, a), (l, l)] : [(l, l), (a, l), (a, a), (l, a)]
                    }
                case .no:
                    switch trieSymbol.symbolType {
                    case .prefix:
                        checkList = [(n, l)]
                    case .postfix:
                        checkList = [(l, n)]
                    case .infix:
                        checkList = [(l, l)]
                    }
                }
                
                for heads in checkList {
                    var currentNode = root
                    append(character: heads.0.rawValue)
                    
                    for char in trieSymbol.lexeme {
                        append(character: char)
                    }
                    
                    append(character: heads.1.rawValue, isTail: true)
                    currentNode.symbol = trieSymbol
                    
                    func append(character: Character, isTail: Bool = false) {
                        if let node = currentNode.children[character] {
                            node.isTail = isTail
                            currentNode = node
                        } else {
                            let newNode = TrieNode(isTail: isTail)
                            currentNode.children[character] = newNode
                            currentNode = newNode
                        }
                    }
                }
            }
            
            return root
        }
    }
}

extension Censor.Compiler.TrieNode: CustomStringConvertible {
    
    public var description: String {
        var output = "\n"
        output += "━━━ 字典树结构 (Trie Structure) ━━━\n"
        output += "Trie Root\n"
        // 递归打印树，并记录已经解释过的特殊符号
        output += describe(node: self, prefix: "", explainedSigns: [])
        output += "\n"
        output += formatSymbolSummary()
        return output
    }

    // MARK: - 1. 符号清单格式化 (聚合路径逻辑)
    private func formatSymbolSummary() -> String {
        let allEntries = collectSymbolEntries(node: self, path: "")
        
        // 按 lexeme 和 type 分组，将不同的上下文符号对 (Sign Pairs) 聚合在一起
        // Key: lexeme + type
        var grouped: [String: (lex: String, type: String, rule: String, contexts: Set<String>)] = [:]
        
        for entry in allEntries {
            let key = "\(entry.symbol.lexeme)_\(entry.symbol.symbolType)"
            let ctxString = "\(entry.leftSign) \(entry.rightSign)"
            
            if var existing = grouped[key] {
                existing.contexts.insert(ctxString)
                grouped[key] = existing
            } else {
                grouped[key] = (
                    "`\(entry.symbol.lexeme)`",
                    entry.symbol.symbolType.description,
                    "\(entry.symbol.spacing)",
                    [ctxString]
                )
            }
        }

        // 按 Lexeme 长度和字母序排序
        let sortedRows = grouped.values.sorted {
            $0.lex.count == $1.lex.count ? $0.lex < $1.lex : $0.lex.count < $1.lex.count
        }

        // --- 宽度自适应计算 ---
        let col1Title = "Lexeme"
        let col2Title = "Contexts"
        let col3Title = "Type"
        let col4Title = "Spacing Rule"
        
        var maxLexWidth = col1Title.count
        var maxCtxWidth = col2Title.count
        var maxTypeWidth = col3Title.count
        var maxRuleWidth = col4Title.count
        
        let processedRows: [(lex: String, ctxs: String, type: String, rule: String)] = sortedRows.map { row in
            let ctxsJoined = row.contexts.sorted().joined(separator: ", ")
            maxLexWidth = max(maxLexWidth, row.lex.count)
            maxCtxWidth = max(maxCtxWidth, ctxsJoined.count)
            maxTypeWidth = max(maxTypeWidth, row.type.count)
            maxRuleWidth = max(maxRuleWidth, row.rule.count)
            return (row.lex, ctxsJoined, row.type, row.rule)
        }

        // --- 构造输出字符串 ---
        let totalWidth = maxLexWidth + maxCtxWidth + maxTypeWidth + maxRuleWidth + 13
        let thickBar = String(repeating: "━", count: totalWidth)
        let thinBar = String(repeating: "─", count: totalWidth)
        
        var table = "━━━ 已注册符号清单 (Registered Symbols) ━━━\n"
        table += "图例 (Legend):\n"
        table += "  □: All (Lit & Space)\n  ■: Lit (Lit & !Space)\n"
        table += "  ○: Space (!Lit & Space)\n  ●: None (!Lit & !Space)\n"
        table += thickBar + "\n"
        
        // 打印表头
        let h1 = col1Title.padding(toLength: maxLexWidth, withPad: " ", startingAt: 0)
        let h2 = col2Title.padding(toLength: maxCtxWidth, withPad: " ", startingAt: 0)
        let h3 = col3Title.padding(toLength: maxTypeWidth, withPad: " ", startingAt: 0)
        let h4 = col4Title.padding(toLength: maxRuleWidth, withPad: " ", startingAt: 0)
        table += " \(h1) │ \(h2) │ \(h3) │ \(h4)\n"
        table += thinBar + "\n"
        
        // 打印数据行
        for row in processedRows {
            let r1 = row.lex.padding(toLength: maxLexWidth, withPad: " ", startingAt: 0)
            let r2 = row.ctxs.padding(toLength: maxCtxWidth, withPad: " ", startingAt: 0)
            let r3 = row.type.padding(toLength: maxTypeWidth, withPad: " ", startingAt: 0)
            let r4 = row.rule.padding(toLength: maxRuleWidth, withPad: " ", startingAt: 0)
            table += " \(r1) │ \(r2) │ \(r3) │ \(r4)\n"
        }
        
        table += thickBar + "\n"
        return table
    }

    // MARK: - 2. 树结构递归描述 (带 Sign 解释逻辑)
    private func describe(node: Censor.Compiler.TrieNode, prefix: String, explainedSigns: Set<Character>) -> String {
        var result = ""
        var updatedExplainedSigns = explainedSigns
        let sortedKeys = node.children.keys.sorted()
        
        for (index, key) in sortedKeys.enumerated() {
            let isLast = index == sortedKeys.count - 1
            let child = node.children[key]!
            let connector = isLast ? "└── " : "├── "
            
            var charDisplay: String
            let isSign = "□■○●".contains(key)
            
            if isSign {
                if !updatedExplainedSigns.contains(key) {
                    switch key {
                    case Censor.Compiler.TrieNode.Sign.all.rawValue:     charDisplay = "\(key) [All]"
                    case Censor.Compiler.TrieNode.Sign.literal.rawValue: charDisplay = "\(key) [Lit]"
                    case Censor.Compiler.TrieNode.Sign.space.rawValue:   charDisplay = "\(key) [Space]"
                    case Censor.Compiler.TrieNode.Sign.none.rawValue:    charDisplay = "\(key) [None]"
                    default: charDisplay = "'\(key)'"
                    }
                    updatedExplainedSigns.insert(key)
                } else {
                    charDisplay = "\(key)"
                }
            } else {
                charDisplay = "'\(key)'"
            }
            
            var symbolInfo = ""
            if let sym = child.symbol {
                symbolInfo = " ➜  \(sym.symbolType.description)(\(sym.lexeme))"
            }
            
            result += prefix + connector + charDisplay + symbolInfo + "\n"
            
            let nextPrefix = prefix + (isLast ? "    " : "│   ")
            result += describe(node: child, prefix: nextPrefix, explainedSigns: updatedExplainedSigns)
        }
        return result
    }

    // MARK: - 3. 辅助：收集完整路径
    private struct SymbolEntry {
        let leftSign: Character
        let lexeme: String
        let rightSign: Character
        let symbol: Censor.Compiler.TrieSymbol
    }

    private func collectSymbolEntries(node: Censor.Compiler.TrieNode, path: String) -> [SymbolEntry] {
        var entries: [SymbolEntry] = []
        
        func traverse(_ n: Censor.Compiler.TrieNode, currentPath: String) {
            if let sym = n.symbol {
                let left = currentPath.first ?? "?"
                let right = currentPath.last ?? "?"
                entries.append(SymbolEntry(leftSign: left, lexeme: sym.lexeme, rightSign: right, symbol: sym))
            }
            for (char, child) in n.children {
                traverse(child, currentPath: currentPath + String(char))
            }
        }
        
        traverse(node, currentPath: "")
        return entries
    }
}
