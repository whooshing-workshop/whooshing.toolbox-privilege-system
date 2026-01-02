extension Censor.Compiler {
    enum SymbolType: String, Hashable, CustomStringConvertible {
        case prefix     = "Prefix"
        case postfix    = "Postfix"
        case infix      = "Infix"
        case none       = "None"
        
        var description: String { self.rawValue }
    }
    
    struct TrieSymbol {
        let lexeme: String
        let symbol: any Token.TokenType
        let symbolType: SymbolType
        let spacing: Spacing
        let allowRepeating: Bool
        
        enum Spacing: CustomStringConvertible {
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
        
        init(
            _ lexeme: String,
            _ symbol: any Token.TokenType,
            _ symbolType: SymbolType,
            spacing: Spacing,
            allowRepeating: Bool = false,
        ) {
            self.symbol = symbol
            self.lexeme = lexeme
            self.symbolType = symbolType
            self.spacing = spacing
            self.allowRepeating = allowRepeating
        }
    }
    

    class TrieNode: @unchecked Sendable {
        private(set) var children: [Character: TrieNode] = [:]
        private(set) var symbol: TrieSymbol? = nil
        
        enum SpacingSign: Character, Sendable {
            case requireSpaceSign = "□"
            case notSpaceSign = "■"
        }
        static var S: Character { SpacingSign.requireSpaceSign.rawValue }
        static var N: Character { SpacingSign.notSpaceSign.rawValue }
        
        static let root = TrieNode.build(from: Token.Symbol.lexemeMap + Token.Delimiter.lexemeMap + Token.Punctuator.lexemeMap)
        
        var isLeaf: Bool { children.isEmpty }
        
        private init(children: [Character : TrieNode] = [:], symbol: TrieSymbol? = nil) {
            self.children = children
            self.symbol = symbol
        }
        
        static func build(from symbols: [TrieSymbol]) -> TrieNode {
            let root = TrieNode()
            
            for trieSymbol in symbols {
                
                // 每个 Symbol 的前后空格均有严格规定，设定存于 TrieSymbol 的 spacing
                // 中，下面列出所有处理情况：
                //
                //          space: 前一个字符必须为空格
                //             \t: 前一个字符必须不是空格
                //             <>: 符号的值，每个 TrieNode 仅存一个字母
                //
                //  --------------------------------------------
                //  |               | 在 Trie 树中的存储链
                //  |               |     一行表示一条
                //  |---------------|---------------------------
                //  |   .symm(true) | space | <> | space |  1  |
                //  |---------------|-------|----|-------|-----|
                //  |  .symm(false) |    \t | <> | \t    |  1  |
                //  |---------------|-------|----|-------|-----|
                //  |    .symm(nil) | space | <> | space |  2  |
                //  |               |    \t | <> | \t    |     |
                //  |---------------|-------|----|-------|-----|
                //  |   .asym(true) | space | <> | \t    |  1  |
                //  |---------------|-------|----|-------|-----|
                //  |  .asym(false) |    \t | <> | space |  1  |
                //  |---------------|-------|----|-------|-----|
                //  |    .asym(nil) | space | <> | \t    |  2  |
                //  |               |    \t | <> | space |     |
                //  |---------------|-------|----|-------|-----|
                //  |          .any |    \t | <> | \t    |  4  |
                //  |               | space | <> | \t    |     |
                //  |               | space | <> | space |     |
                //  |               |    \t | <> | space |     |
                //  |---------------|-------|----|-------|-----|
                //  |         .none |    \t | <> | \t    |  1  |
                //  --------------------------------------------
                //
                let checkList: [(SpacingSign, SpacingSign)]
                let s = SpacingSign.requireSpaceSign
                let n = SpacingSign.notSpaceSign
                switch trieSymbol.spacing {
                case .symm(let left):
                    checkList = left == nil ? [(s, s), (n, n)] : (left! ? [(s, s)] : [(n, n)])
                case .asym(let left):
                    checkList = left == nil ? [(s, n), (n, s)] : (left! ? [(s, n)] : [(n, s)])
                case .any:
                    checkList = [(n, n), (s, n), (s, s), (n, s)]
                case .none:
                    checkList = [(n, n)]
                }
                
                for heads in checkList {
                    var currentNode = root
                    append(character: heads.0.rawValue)
                    
                    for char in trieSymbol.lexeme {
                        append(character: char)
                    }
                    
                    append(character: heads.1.rawValue)
                    currentNode.symbol = trieSymbol
                    
                    func append(character: Character) {
                        if let node = currentNode.children[character] {
                            currentNode = node
                        } else {
                            let newNode = TrieNode()
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
        table += "  □: Space\n"
        table += "  ■: None Space\n"
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
                    case Censor.Compiler.TrieNode.SpacingSign.requireSpaceSign.rawValue:    charDisplay = "\(key) [Space]"
                    case Censor.Compiler.TrieNode.SpacingSign.notSpaceSign.rawValue:        charDisplay = "\(key) [None]"
                        
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
                symbolInfo = " -> \(sym.symbolType.description)(\(sym.lexeme))"
            }
            
            result += prefix + connector + charDisplay + symbolInfo + "\n"
            
            let nextPrefix = prefix + (isLast ? "    " : "│   ")
            result += describe(node: child, prefix: nextPrefix, explainedSigns: updatedExplainedSigns)
        }
        return result
    }

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
