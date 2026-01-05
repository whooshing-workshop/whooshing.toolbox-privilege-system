import Testing
import Foundation
@testable import Censor

/// Parser 测试辅助工具
enum ParserTestHelpers {
    
    /// 解析源代码并断言 AST 描述包含指定的片段（顺序不敏感，或按列表顺序检查包含）
    static func assertAST(_ source: String, contains snippets: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        let result = Censor.Lexer(source: source).scanTokens()
        let parser = Censor.Parser(tokens: result.tokens, source: source)
        let parseResult = parser.parse()
        
        guard let ast = parseResult.ast else {
            #expect(Bool(false), "解析失败，未生成 AST：\(source)", sourceLocation: sourceLocation)
            return
        }
        
        let desc = ast.description
        for snippet in snippets {
            #expect(desc.contains(snippet), "AST 描述未包含预期片段: \(snippet)\n实际 AST: \(desc)", sourceLocation: sourceLocation)
        }
        
        #expect(parseResult.diagnostics.isEmpty, "预期无错误，实际错误: \(parseResult.diagnostics)", sourceLocation: sourceLocation)
    }

    /// 解析源代码并断言发生特定错误
    static func assertError(_ source: String, errorSnippet: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let result = Censor.Lexer(source: source).scanTokens()
        let parser = Censor.Parser(tokens: result.tokens, source: source)
        let parseResult = parser.parse()
        
        #expect(!parseResult.diagnostics.isEmpty, "预期报错但未报错: \(source)", sourceLocation: sourceLocation)
        let errors = parseResult.diagnostics.compactMap { $0 as? Censor.Error }.map { $0.prettyDescription(in: source) }.joined(separator: "\n")
        #expect(errors.contains(errorSnippet), "错误信息未包含预期片段: \(errorSnippet)\n实际错误: \(errors)", sourceLocation: sourceLocation)
    }
}
