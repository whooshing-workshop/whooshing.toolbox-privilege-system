import Testing
import Foundation
@testable import Censor

@Suite("Lexer 终极边界与符号碰撞测试")
struct LexerUltimateBoundaryTests {

    // MARK: - 专项 5: 符号链条与值传递 (The Operator Chain)
    @Test("连续符号的值传递压力测试", arguments: [
        // 1. 极致的后缀连写 (验证 N+N 路径补全)
        ("a!!!!!!!!", [
            "Literal.IDENT(a)", "Symbol.F_CAST", "Symbol.F_CAST", "Symbol.F_CAST", "Symbol.F_CAST",
            "Symbol.F_CAST", "Symbol.F_CAST", "Symbol.F_CAST", "Symbol.F_CAST"
        ]),
        // 2. 后缀接中缀再接前缀 (物理碰撞最复杂场景)
        ("a! + !b", [
            "Literal.IDENT(a)", "Symbol.F_CAST", "Symbol.Infix(+)", "Symbol.NOT", "Literal.IDENT(b)"
        ]),
        // 3. 连续问号的贪婪与回退 (?? vs ?)
        ("a ?? ? b", [
            "Literal.IDENT(a)", "Symbol.NIL_COAL", "Symbol.TERNARY_QUEST", "Literal.IDENT(b)"
        ]),
        // 4. 空合与解包的密集碰撞
        ("a ?? ?? ??", [
            "Literal.IDENT(a)", "Symbol.NIL_COAL", "Symbol.NIL_COAL", "Symbol.NIL_COAL"
        ])
    ])
    func testOperatorChains(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "符号链条解析失败\n\(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 6: 标点透明度测试 (Punctuation Transparency)
    @Test("标点作为物理边界的透明度感知", arguments: [
        // 1. 右括号作为实部的吸附力
        ("(a)!", ["Punctuator.PAREN_L", "Literal.IDENT(a)", "Punctuator.PAREN_R", "Symbol.F_CAST"]),
        // 2. 逗号作为虚部的引导力 (逗号后应视为 S)
        ("a, !b", ["Literal.IDENT(a)", "Delimiter.COMMA", "Symbol.NOT", "Literal.IDENT(b)"]),
        // 3. 冒号在不同语境下的虚实切换
        ("a : -b", ["Literal.IDENT(a)", "Symbol.TERNARY_COLON", "Symbol.Prefix(-)", "Literal.IDENT(b)"]),
        // 4. 嵌套方括号
        ("a[b[i]]!", [
            "Literal.IDENT(a)", "Punctuator.SQUARE_L", "Literal.IDENT(b)",
            "Punctuator.SQUARE_L", "Literal.IDENT(i)", "Punctuator.SQUARE_R",
            "Punctuator.SQUARE_R", "Symbol.F_CAST"
        ])
    ])
    func testPunctuationContext(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "符号链条解析失败\n\(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 7: 标识符与符号的边缘混淆 (Identifier Edge Cases)
    @Test("标识符与操作符的贴身肉搏", arguments: [
        // 1. 标识符内含 e (非科学计数法)
        ("value_e+1", ["Literal.IDENT(value_e)", "Symbol.Infix(+)", "Literal.INT"]),
        // 2. 标识符结尾紧跟操作符
        ("isTrue! & hasValue?", [
            "Literal.IDENT(isTrue)", "Symbol.F_CAST", "Symbol.Infix(&)",
            "Literal.IDENT(hasValue)", "Symbol.OP_CHAIN"
        ]),
        // 3. 下划线开头的特殊标识符
        ("_ + _", ["Literal.IDENT(_)", "Symbol.Infix(+)", "Literal.IDENT(_)"])
    ])
    func testIdentifierEdges(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "符号链条解析失败\n\(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 8: 空格与注释的干扰 (Whitespace & Trivia)
    @Test("极端空格干扰测试", arguments: [
        // 1. 混合全角/半角/制表符 (假设编译器只支持半角，全角应视为意外或分隔)
        ("a \t \n + \r b", ["Literal.IDENT(a)", "Symbol.Infix(+)", "Literal.IDENT(b)"]),
        // 2. 紧凑的运算符与数字 (1+ +1)
        ("1 + +1", ["Literal.INT", "Symbol.Infix(+)", "Symbol.Prefix(+)", "Literal.INT"]),
        // 3. 多个连续空格的过滤
        ("a        ==        b", ["Literal.IDENT(a)", "Symbol.Infix(==)", "Literal.IDENT(b)"]),
        ("a\n\n\n==\n\nb", ["Literal.IDENT(a)", "Symbol.Infix(==)", "Literal.IDENT(b)"]),
        ("a\t\t\t==\t\tb", ["Literal.IDENT(a)", "Symbol.Infix(==)", "Literal.IDENT(b)"]),
        ("a\t\n\t==\n\tb", ["Literal.IDENT(a)", "Symbol.Infix(==)", "Literal.IDENT(b)"])
    ])
    func testWhitespaceTrivia(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "符号链条解析失败\n\(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }
}
