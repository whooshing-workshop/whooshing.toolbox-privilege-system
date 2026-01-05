import ErrorHandle
import Foundation

extension Censor {
    public class Parser {
        // Token 定义在 Censor 命名空间中
        typealias Token = Censor.Token
        typealias AST = Censor.AST
        
        // MARK: - State
        
        let tokens: [Token]
        let source: String
        var current = 0
        var diagnostics: [Censor.Error] = []

        // MARK: - Rule Registry
        
        static let ruleLexemeMap: [String: any Censor.Rule.Define] = {
            var map: [String: any Censor.Rule.Define] = [:]
            for rule in Censor.Rule.all {
                map[rule.keyword.lexeme] = rule
            }
            return map
        }()

        // MARK: - Lifecycle
        
        init(tokens: [Token], source: String) {
            self.tokens = tokens
            self.source = source
        }
        
        // MARK: - Entry Point

        public func parse() -> Result {
            if tokens.isEmpty || (tokens.count == 1 && tokens.first?.content is Censor.Extra && (tokens.first?.content as? Censor.Extra) == .eof) {
                return Result(ast: nil, diagnostics: [], source: source)
            }
            
            let ast = parseStatement()
            
            return Result(ast: ast, diagnostics: diagnostics, source: source)
        }
        
        // MARK: - Statement Parsing
        
        func parseStatement() -> Censor.AST? {
            // 检查当前 Token 是否触发特定的 Rule (Keyword Match)
            if let keyword = peek().content as? Censor.Keyword.Define {
                if let rule = Self.ruleLexemeMap[keyword.lexeme] {
                    return rule.parse(parser: self)
                }
            }
            
            return parseExpression()
        }
    }
}

extension Censor.Parser {
    public struct Result {
        public let ast: Censor.AST?
        public let diagnostics: [any Swift.Error]
        public let source: String
        
        public var hasErrors: Bool {
            !diagnostics.isEmpty
        }
    }
}

// MARK: - Logs
extension Censor.Parser.Result: CustomStringConvertible {
    public var description: String {
        guard ast != nil || !diagnostics.isEmpty else { return "语法分析: 空输入或无结果" }

        if hasErrors {
            return formatErrorReport()
        } else {
            return formatASTReport()
        }
    }

    private func formatASTReport() -> String {
        let astDesc = ast?.description ?? " (Nil AST)"
        let title = "语法分析通过: AST 生成成功"
        
        let lines = astDesc.components(separatedBy: .newlines) + [title]
        let width = max(lines.map { $0.count }.max() ?? 0, 20)
        
        let bar = String(repeating: "━", count: width)
        
        var output = "\n" + title + "\n"
        output += bar
        output += astDesc + "\n"
        output += bar + "\n"
        return output
    }

    private func formatErrorReport() -> String {
        let title = " 语法分析失败, 找到 \(diagnostics.count) 个错误"
        var errorTexts: [String] = [title]
        
        var errorDetails: [String] = []
        for (index, error) in diagnostics.enumerated() {
            var detail = " [错误 \(index + 1)]\n"
            if let censorError = error as? Censor.Error {
                detail += censorError.prettyDescription(in: source)
            } else {
                detail += " \(error.localizedDescription)"
            }
            errorDetails.append(detail)
            errorTexts.append(contentsOf: detail.components(separatedBy: .newlines))
        }
        
        let width = max(errorTexts.map { $0.count }.max() ?? 0, 20)
        let thickLine = String(repeating: "━", count: width)
        let thinLine  = String(repeating: "─", count: width)
        
        var output = "\n" + thickLine + "\n"
        output += title + "\n"
        output += thickLine + "\n"
        
        for (index, detail) in errorDetails.enumerated() {
            if index > 0 { output += thinLine + "\n" }
            output += detail + "\n"
        }
        
        output += thickLine + "\n"
        return output
    }
}
