import Testing
import Foundation
@testable import Censor

@Suite("Lexer 深度压力与全量路径测试")
struct LexerFullCoverageTests {

    // MARK: - 专项 1: 符号缀位识别 (30个用例)
    @Test("缀位感知测试", arguments: [
        // 格式: (源码, 期望的 TokenType 描述)
        // --- 正负号 (复用 + 和 -) ---
        ("+1", "Symbol.Prefix(+)"),       // 行首 Prefix
        (" -1", "Symbol.Prefix(-)"),      // 空格后 Prefix
        ("1+1", "Symbol.Infix(+)"),       // 紧凑 Infix
        ("1-1", "Symbol.Infix(-)"),       // 紧凑 Infix
        ("1 + 1", "Symbol.Infix(+)"),     // 标准 Infix
        ("(+1)", "Symbol.Prefix(+)"),     // 左括号后 Prefix
        ("[ -1 ]", "Symbol.Prefix(-)"),   // 中括号后 Prefix
        ("a +1", "Symbol.Prefix(+)"),     // 符号后 Prefix
        
        // --- 逻辑与比较 (组合符号) ---
        ("a==b", "Symbol.Infix(==)"),
        ("a!=b", "Symbol.Infix(!=)"),
        ("a<=b", "Symbol.Infix(<=)"),
        ("a>=b", "Symbol.Infix(>=)"),
        ("!true", "Symbol.NOT"),
        ("flag!", "Symbol.F_CAST"),
        ("!flag!", "Symbol.NOT"),
        
        // --- 物理边界极端情况 ---
        ("a?", "Symbol.OP_CHAIN"),
        ("??", "Symbol.NIL_COAL"),
        ("a??b", "Symbol.NIL_COAL"),
        ("a ?? b", "Symbol.NIL_COAL"),
        
        // --- 标点符号与运算符混用 ---
        ("func(a+b)", "Symbol.Infix(+)"),
        ("array[i-1]", "Symbol.Infix(-)"),
        ("[!ready]", "Symbol.NOT"),
        ("a, -b", "Delimiter.COMMA"),
        ("a : -b", "Symbol.TERNARY_COLON"),
        
        ("a&b", "Symbol.Infix(&)"),
        ("a|b", "Symbol.Infix(|)")
    ])
    func testOperatorContexts(input: String, expected: String) {
        let result = Censor.Lexer(source: input).scanTokens()
        // 找到非 ID 的那个操作符 Token 进行验证
        let target = result.tokens.first { isOperator($0) }
        guard !result.hasErrors else {
            #expect(Bool(false))
            print(result)
            return
        }
        guard let t = target else {
            #expect(Bool(false), "未能识别操作符: \(input)")
            return
        }
        #expect(t.content.description == expected)
    }

    // MARK: - 专项 2: 字面量与歧义消除 (20个用例)
    @Test("复杂字面量测试", arguments: [
        // --- 字符串与转义 ---
        ("\"\"", "Literal.STRING"),
        ("\" \"", "Literal.STRING"),
        ("\"\\\"\"", "Literal.STRING"),   // 转义引号
        ("\"\\\\\"", "Literal.STRING"),   // 转义反斜杠
        
        // --- 单引号字面量 (Date vs Char) ---
        ("'a'", "Literal.CHAR"),
        ("'2025-12-31T23:59:59Z'", "Literal.DATE"),
        
        // --- 数字与点号歧义 ---
        ("0.1", "Literal.DECIMAL"),
        (".1", "Symbol.Infix(.)"),          // 你的逻辑点号后需数字才是小数
        ("1.", "Literal.INT"),            // 整数后接点
        ("1.0.1", "Literal.DECIMAL"),     // 解析 1.0 后接 .1
        ("0", "Literal.INT"),
        ("9223372036854775807", "Literal.INT"), // Int64 Max
        
        // --- 标识符与关键字 ---
        ("true", "Literal.BOOL"),
        ("false", "Literal.BOOL"),
        ("nil", "Literal.IDENT(nil)"),
        ("IN", "Keyword.IN"),
        ("_temp", "Literal.IDENT(_temp)"),
        ("a1", "Literal.IDENT(a1)")
    ])
    func testLiteralEdges(input: String, expected: String) {
        let result = Censor.Lexer(source: input).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false))
            print(result)
            return
        }
        #expect(result.tokens[0].content.description == expected)
    }

    // MARK: - 专项 3: 结构化与嵌套 (10个用例)
    @Test("复杂语句流测试")
    func testComplexFlow() {
        let source = "(a + b) * -c / (d ?? 0) >= 100 == !false"
        let result = Censor.Lexer(source: source).scanTokens()
        
        let types = result.tokens.map { $0.content.description }
        
        // 关键点校验
        #expect(types[6] == "Symbol.Prefix(-)")       // -c
        #expect(types[11] == "Symbol.NIL_COAL")       // d ?? 0
        #expect(types[16] == "Symbol.Infix(==)")      // ... == !
        #expect(types[17] == "Symbol.NOT")            // !false
        #expect(!result.hasErrors)
    }

    @Test("极端紧凑嵌套测试")
    func testTightNesting() {
        let source = "1+(2-(3*(4/5)))"
        let result = Censor.Lexer(source: source).scanTokens()
        
        #expect(!result.hasErrors)
    }
}

// MARK: - 辅助判定函数
private func isOperator(_ type: Censor.Token) -> Bool {
    let name = type.content.description
    return name.contains("Symbol") || name.contains("NOT") || name.contains("NIL_COAL") || name.contains("Delimiter")
}
