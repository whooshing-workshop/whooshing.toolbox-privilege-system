import Testing
import Foundation
@testable import Censor

@Suite("Lexer 极端路径与难题专项测试")
struct LexerAdvancedChallengeTests {
    // MARK: - 专项 1: 复杂逻辑流 (Logic Hell)
    @Test("长链条逻辑与三目嵌套", arguments: [
        // 1. 连续后缀与三目嵌套
        ("a!! ? b?.c! : d ?? !e", [
            "Literal.IDENT(a)", "Symbol.F_CAST", "Symbol.F_CAST", "Symbol.TERNARY_QUEST",
            "Literal.IDENT(b)", "Symbol.OP_CHAIN", "Delimiter.DOT", "Literal.IDENT(c)", "Symbol.F_CAST",
            "Symbol.TERNARY_COLON", "Literal.IDENT(d)", "Symbol.NIL_COAL", "Symbol.NOT", "Literal.IDENT(e)"
        ]),
        // 2. 负号在复杂表达式中的多次出现
        ("-(a - -b) * -1", [
            "Symbol.Prefix(-)", "Punctuator.PAREN_L", "Literal.IDENT(a)", "Symbol.Infix(-)",
            "Symbol.Prefix(-)", "Literal.IDENT(b)", "Punctuator.PAREN_R", "Symbol.Infix(*)",
            "Symbol.Prefix(-)", "Literal.INT"
        ]),
        // 3. 比较运算符链
        ("a!=b==c>=d<=e>f<g", [
            "Literal.IDENT(a)", "Symbol.Infix(!=)", "Literal.IDENT(b)", "Symbol.Infix(==)",
            "Literal.IDENT(c)", "Symbol.Infix(>=)", "Literal.IDENT(d)", "Symbol.Infix(<=)",
            "Literal.IDENT(e)", "Symbol.Infix(>)", "Literal.IDENT(f)", "Symbol.Infix(<)", "Literal.IDENT(g)"
        ])
    ])
    func testLogicFlows(source: String, expectedTypes: [String]) {
        let result = Censor.Compiler.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false))
            print(result)
            return
        }
        let actualTypes = result.tokens.filter { $0.symbol.description != "EOF" }.map { $0.symbol.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 2: 极端紧凑嵌套 (The Compression Test)
    @Test("无空格物理压力测试", arguments: [
        // 1. 深度括号嵌套（测试右括号作为实部的吸附力）
        ("((1+2)*3)!!", [
            "Punctuator.PAREN_L", "Punctuator.PAREN_L", "Literal.INT", "Symbol.Infix(+)", "Literal.INT",
            "Punctuator.PAREN_R", "Symbol.Infix(*)", "Literal.INT", "Punctuator.PAREN_R",
            "Symbol.F_CAST", "Symbol.F_CAST"
        ]),
        // 2. 数组索引内嵌套负号与逻辑
        ("a[i - -1][!j]", [
            "Literal.IDENT(a)", "Punctuator.SQUARE_L", "Literal.IDENT(i)", "Symbol.Infix(-)",
            "Symbol.Prefix(-)", "Literal.INT", "Punctuator.SQUARE_R",
            "Punctuator.SQUARE_L", "Symbol.NOT", "Literal.IDENT(j)", "Punctuator.SQUARE_R"
        ]),
        // 3. 紧凑的问号空合组合
        ("a??b ? c : d!!", [
            "Literal.IDENT(a)", "Symbol.NIL_COAL", "Literal.IDENT(b)",
            "Symbol.TERNARY_QUEST", "Literal.IDENT(c)", "Symbol.TERNARY_COLON",
            "Literal.IDENT(d)", "Symbol.F_CAST", "Symbol.F_CAST"
        ])
    ])
    func testTightCompression(source: String, expectedTypes: [String]) {
        let result = Censor.Compiler.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false))
            print(result)
            return
        }
        let actualTypes = result.tokens.filter { $0.symbol.description != "EOF" }.map { $0.symbol.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 3: 不支持语法的“降级”拆解测试 (Degradation Tests)
    // 编译器不支持位运算和科学计数法，所以 Lexer 必须能把它们拆散
    @Test("非支持语法的强制拆解", arguments: [
        // 1. 伪科学计数法 (1.2e+5 -> DECIMAL(1.2) + IDENT(e) + Prefix(+) + INT(5))
        ("1.2e+5", ["Literal.DECIMAL", "Literal.IDENT(e)", "Symbol.Infix(+)", "Literal.INT"]),
        // 2. 伪位运算 (a&b -> IDENT(a) + INVALID(&) + IDENT(b))
        ("a&b", ["Literal.IDENT(a)", "Symbol.Infix(&)", "Literal.IDENT(b)"]),
        // 3. 多个点号 (1.2.3.4 -> DECIMAL(1.2) + DOT(.) + DECIMAL(3.4))
        ("1.2.3.4", ["Literal.DECIMAL", "Delimiter.DOT", "Literal.DECIMAL"])
    ])
    func testUnsupportedGrammar(source: String, expectedTypes: [String]) {
        let result = Censor.Compiler.Lexer(source: source).scanTokens()
        let actualTypes = result.tokens.filter { $0.symbol.description != "EOF" }.map { $0.symbol.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 4: 边界防御与鲁棒性 (Edge Defense)
    @Test("非法与半闭合结构")
    func testRobustness() {
        // 1. 未闭合的括号地狱
        let res1 = Censor.Compiler.Lexer(source: "((((1+2)").scanTokens()
        #expect(!res1.hasErrors) // Lexer 不管闭合，那是 Parser 的事
        #expect(res1.tokens.count == 9)

        // 2. 异常空白符混入
        let res2 = Censor.Compiler.Lexer(source: "a\u{00A0}+\t\nb").scanTokens() // 包含不间断空格
        #expect(res2.tokens.filter { $0.symbol.description == "Symbol.Infix(+)" }.count == 1)

        // 3. 连续的操作符但无操作数 (!+-+!!)
        let res3 = Censor.Compiler.Lexer(source: "!+-+!!").scanTokens()
        // 这考验 Trie 树如何处理一串只有符号的输入
        #expect(!res3.hasErrors)
    }
}
