import Testing
@testable import Censor

@Suite("Parser: 错误处理与鲁棒性")
struct ParserErrorTests {

    @Test("语法错误捕获")
    func testSyntaxErrors() {
        // 1. IN 缺少 Domain
        ParserTestHelpers.assertError("IN { }", errorSnippet: "IN 语句后需跟随 Domain 表达式")
        
        // 2. IN 缺少 {
        ParserTestHelpers.assertError("IN User age > 18", errorSnippet: "IN 语句后需跟随代码块 '{'")
        
        // 3. IN 代码块为空
        ParserTestHelpers.assertError("IN User { }", errorSnippet: "IN 代码块不能为空")
        
        // 4. IN 代码块多于一条语句
        ParserTestHelpers.assertError("IN User { a > 1; b > 2 }", errorSnippet: "IN 代码块内仅包含一条语句")
        
        // 5. 数组下标非整数
        ParserTestHelpers.assertError("arr[a]", errorSnippet: "数组下标必须是整数常量")
        
        // 6. 括号不匹配
        ParserTestHelpers.assertError("(1 + 2", errorSnippet: "预期在表达式后输入 ')'")
    }
    
    @Test("边缘错误场景")
    func testEdgeErrors() {
        // 1. 无效的 Top-level Token
        // }
        // Parser parseStatement requires recognizable start (IN or Expression)
        // If "}", scan tokens ok. parseExpression might fail or return nil.
        // Parser.parse expects one statement.
        // } is right brace. Not a prefix expression start.
        // Should parseExpression return nil? Or throw?
        // Parser `parseStatement` calls `parseExpression`.
        // `parseExpression` returns nil if token not prefix.
        // Then `consume(Symbol.Semicolon)`.
        // If nil returned, it simply returns nil? Or error?
        // Let's verify behavior. If returns nil, AST is nil. Diagnostics?
        // Current Parser doesn't enforce "Must parse something".
        // But if AST is nil, `assertAST` fails.
        // `assertError` checks diagnostics.
        
        // Let's try explicit syntax error in Expression
        // 1 + 
        ParserTestHelpers.assertError("1 +", errorSnippet: "无法解析符号: EOF")
        
        // 2. Missing comma in args
        // f(1 2)
        ParserTestHelpers.assertError("f(1 2)", errorSnippet: "预期在参数列表后输入 ')'")
        
        // 3. Invalid array content
        // [1, , 2]
        ParserTestHelpers.assertError("[1, , 2]", errorSnippet: "无法解析符号: Delimiter.COMMA")
        
        // 4. Missing closing bracket
        // [1, 2
        ParserTestHelpers.assertError("[1, 2", errorSnippet: "预期在数组元素后输入 ']'")
    }
}
