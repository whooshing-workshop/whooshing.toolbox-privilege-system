extension Censor.Compiler {
    struct Error: Swift.Error, CustomStringConvertible {
        let kind: Kind
        let range: SourceRange
        let message: String
        let snippet: String?
        
        enum Kind: String, Sendable {
            case lexical        = "词法错误"        // 词法错误：非法字符、未闭合字符串
            case syntactic      = "语法错误"        // 语法错误：缺少括号、不符合文法
            case semantic       = "语义错误"        // 语义错误：类型不匹配、变量未定义
            case `internal`     = "编译器内部错误"   // 编译器内部故障
        }

        /// 格式化输出，方便在控制台查看
        var description: String {
            let location = range.start
            return """
            [\(kind.rawValue)] 发生在 \(location.line) 行, \(location.column) 列:
            \(message)
            """
        }
    }
}

extension Censor.Compiler.Error {
    func prettyDescription(in source: String) -> String {
        let lines = source.components(separatedBy: .newlines)
        let startLoc = range.start
        let endLoc = range.end
        
        let lineIndex = startLoc.line
        guard lineIndex > 0 && lineIndex <= lines.count else {
            return " [\(range.description)] \(message)"
        }
        
        let errorLine = lines[lineIndex - 1]
        let lineNumStr = "\(lineIndex)"
        let gutter = " \(lineNumStr) │ "
        
        var output = ""
        output += " 位置: \(range.description)\n"
        output += " 错误: \(message)\n"
        output += "\(gutter)\(errorLine)\n"
        
        // 计算对齐空格：gutter 的宽度 + startLoc.column - 1
        let leadingPadding = String(repeating: " ", count: gutter.count + startLoc.column - 1)
        
        var marker = "^"
        if startLoc.line == endLoc.line {
            let length = max(0, endLoc.column - startLoc.column)
            marker += String(repeating: "~", count: length)
        } else {
            let length = max(0, errorLine.count - startLoc.column)
            marker += String(repeating: "~", count: length) + "..."
        }
        
        output += "\(leadingPadding)\(marker)"
        return output
    }
}

extension Censor.Compiler.Error.Kind {
    var description: String { self.rawValue }
}
