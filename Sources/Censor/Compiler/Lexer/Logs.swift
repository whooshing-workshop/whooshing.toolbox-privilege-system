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
        let maxPreview = 30
        let previewTokens = Array(tokens.prefix(maxPreview))
        
        // 1. 预计算每一列的最大宽度
        var maxPosWidth = "Location".count // 预留表头宽度
        var maxTypeWidth = "Type".count
        var maxLexemeWidth = "Lexeme".count

        for token in previewTokens {
            let posStr = "[\(token.location.line):\(token.location.column)]"
            let typeStr = getTypeName(token.type)
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
            let pos = "[\(token.location.line):\(token.location.column)]".padding(toLength: maxPosWidth, withPad: " ", startingAt: 0)
            let typeName = getTypeName(token.type).padding(toLength: maxTypeWidth, withPad: " ", startingAt: 0)
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

    // 内部辅助：获取类型名称字符串
    private func getTypeName(_ type: Censor.Compiler.Token.TokenType) -> String {
        if let lit = type as? Censor.Compiler.Token.Literal {
            return "Literal.\(lit.name)"
        } else if let sym = type as? Censor.Compiler.Token.Symbol {
            return "Symbol.\(sym.name)"
        } else if let ext = type as? Censor.Compiler.Token.Extra {
            return ext.name
        }
        return "Unknown"
    }
}

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
        case .bracket(let type, let dir):
            let dirStr = dir == .left ? "L" : "R"
            return "\(type)_\(dirStr)"
            
        case .prefixOperator(let op):   return op.description
        case .postfixOperator(let op):  return op.description
        case .infixOperator(let op):    return op.description
        case .ternary(let part):        return "TERNARY_\(part)"
            
        case .not:           return "NOT"
        case .forceCast:     return "F_CAST"
        case .nilCoalescing: return "NIL_COAL"
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

extension Censor.Compiler.Token: CustomStringConvertible {
    public var description: String {
        // 1. 格式化位置信息，例如 [1:12]
        let pos = "[\(location.line):\(location.column)]"
        let paddedPos = pos.padding(toLength: 10, withPad: " ", startingAt: 0)
        
        // 2. 获取类型名称
        var typeName = ""
        if let lit = type as? Censor.Compiler.Token.Literal {
            typeName = "Literal.\(lit.name)"
        } else if type is Censor.Compiler.Token.Symbol {
            // 符号类直接显示 lexeme 往往更直观
            typeName = "Symbol"
        } else if let ext = type as? Censor.Compiler.Token.Extra {
            typeName = ext.name
        } else {
            typeName = "Unknown"
        }
        
        let paddedType = typeName.padding(toLength: 18, withPad: " ", startingAt: 0)
        
        // 3. 组装最终行
        // 如果 lexeme 包含换行符，将其替换为 \n 符号，避免破坏 Log 结构
        let cleanLexeme = lexeme.replacingOccurrences(of: "\n", with: "\\n")
        
        return "\(paddedPos) │ \(paddedType) │ \(cleanLexeme)"
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
