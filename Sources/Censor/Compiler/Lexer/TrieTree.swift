extension Censor.Compiler {
    enum SymbolType: Hashable {
        case prefix, postfix, infix
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
        
        enum SpacingSign: Character, Sendable {
            case requireSpaceSign = " "
            case notSpaceSign = "\t"
        }
        static var S: Character { SpacingSign.requireSpaceSign.rawValue }
        static var N: Character { SpacingSign.notSpaceSign.rawValue }
        
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
                //  |   .must(true) | space | <> | space |  1  |
                //  |---------------|-------|----|-------|-----|
                //  |  .must(false) | space | <> | space |     |
                //  |               | space | <> | \t    |  3  |
                //  |               |    \t | <> | space |     |
                //  |---------------|-------|----|-------|-----|
                //  |  .allow(true) | space | <> | space |     |
                //  |               |    \t | <> | \t    |  2  |
                //  |---------------|-------|----|-------|-----|
                //  | .allow(false) |    \t | <> | \t    |     |
                //  |               | space | <> | \t    |     |
                //  |               | space | <> | space |  4  |
                //  |               |    \t | <> | space |     |
                //  |---------------|-------|----|-------|-----|
                //  |            .no|    \t | <> | \t    |  1  |
                //  --------------------------------------------
                //
                let checkList: [(SpacingSign, SpacingSign)]
                let s = SpacingSign.requireSpaceSign
                let n = SpacingSign.notSpaceSign
                switch trieSymbol.spacing {
                case .must(let symm):
                    checkList = symm ? [(s, s)] : [(s, s), (s, n), (n, s)]
                case .allow(let symm):
                    checkList = symm ? [(s, s), (n, n)] : [(n, n), (s, n), (s, s), (n, s)]
                case .no:
                    checkList = [(n, n)]
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
