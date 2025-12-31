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
    func prettyPrint(in source: String) {
        let lineIndex = range.start.line
        let lines = source.components(separatedBy: .newlines)
        
        guard lineIndex > 0 && lineIndex <= lines.count else {
            print(description)
            return
        }
        
        let errorLine = lines[lineIndex - 1]
        let column = range.start.column
        
        print("--------------------------------------------------")
        print(description)
        print("\(lineIndex) | \(errorLine)")
        
        // 打印指向符 ^
        let padding = String(repeating: " ", count: String(lineIndex).count + 3 + column - 1)
        print("\(padding)^")
        print("--------------------------------------------------")
    }
}
