import Foundation

extension Censor {
    struct SourceLocation: Sendable, Equatable {
        let offset: Int /// 全局字符偏移量（从 0 开始），用于在原始 String 中快速切片
        let line: Int   /// 行号（通常从 1 开始计数）
        let column: Int /// 列号（通常从 1 开始计数）
        let sourceId: String? = nil
        
        func offset(by i: Int) -> Self {
            .init(offset: offset, line: line, column: column + i)
        }
    }
    
    struct SourceRange: Sendable, Equatable {
        let start: SourceLocation
        let end: SourceLocation
    }
    
    struct Token {
        let lexeme: String
        let content: TokenUnit
        let range: SourceRange
        
        init(
            _ lexeme: String,
            _ symbol: TokenUnit,
            range: SourceRange? = nil
        ) {
            self.content = symbol
            self.lexeme = lexeme
            self.range = range ?? .init(start: .init(offset: 0, line: 0, column: 0), end: .init(offset: 0, line: 0, column: 0))
        }
        
        func set(range: SourceRange) -> Self {
            .init(lexeme, content, range: range)
        }
    }
}

// MARK: - Logs

extension Censor.SourceLocation: CustomStringConvertible {
    public var description: String {
        let file = sourceId != nil ? "\(sourceId!):" : ""
        return "\(file)\(line):\(column)"
    }
}

extension Censor.SourceRange: CustomStringConvertible {
    public var description: String {
        if start == end {
            return start.description
        } else if start.line == end.line {
            // 同一行: 1:5-12 (第1行，第5到12列)
            return "\(start.description)-\(end.column)"
        } else {
            // 跨行: 1:5-2:10 (第1行第5列 到 第2行第10列)
            return "\(start.description)-\(end.description)"
        }
    }
}
