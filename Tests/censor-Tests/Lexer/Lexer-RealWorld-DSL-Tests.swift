import Testing
import Foundation
@testable import Censor

@Suite("Lexer 真实 DSL 场景综合测试")
struct LexerDSLSimulationTests {

    // MARK: - 专项 1: 复杂表达式与混合嵌套 (The Multi-Type Mashup)
    // 覆盖：字面量、运算符、可选链、强制解包、数组、括号
    @Test("综合逻辑流测试", arguments: [
        // 1. 典型的权限校验逻辑
        ("user.roles[0] == \"admin\" & (is_active!! | expiry_date > '2026-01-01T00:00:00Z')", [
            "Literal.IDENT(user)", "Delimiter.DOT", "Literal.IDENT(roles)", "Punctuator.SQUARE_L", "Literal.INT", "Punctuator.SQUARE_R",
            "Symbol.Infix(==)", "Literal.STRING", "Symbol.Infix(&)", "Punctuator.PAREN_L",
            "Literal.IDENT(is_active)", "Symbol.F_CAST", "Symbol.F_CAST", "Symbol.Infix(|)",
            "Literal.IDENT(expiry_date)", "Symbol.Infix(>)", "Literal.DATE", "Punctuator.PAREN_R"
        ]),
        
        // 2. 密集数学运算与负号转换 (降级测试)
        ("-(100.5 * 2) + -(item.price / -1.0)", [
            "Symbol.Prefix(-)", "Punctuator.PAREN_L", "Literal.DECIMAL", "Symbol.Infix(*)", "Literal.INT", "Punctuator.PAREN_R",
            "Symbol.Infix(+)", "Symbol.Prefix(-)", "Punctuator.PAREN_L",
            "Literal.IDENT(item)", "Delimiter.DOT", "Literal.IDENT(price)", "Symbol.Infix(/)", "Symbol.Prefix(-)", "Literal.DECIMAL", "Punctuator.PAREN_R"
        ]),
        
        // 3. 可选链与三目嵌套
        ("data?.items[count-1] ? \"has_data\" : nil", [
            "Literal.IDENT(data)", "Symbol.OP_CHAIN", "Delimiter.DOT", "Literal.IDENT(items)",
            "Punctuator.SQUARE_L", "Literal.IDENT(count)", "Symbol.Infix(-)", "Literal.INT", "Punctuator.SQUARE_R",
            "Symbol.TERNARY_QUEST", "Literal.STRING", "Symbol.TERNARY_COLON", "Keyword.NULL"
        ]),
        
        // 4. UUID 与标识符碰撞
        ("id == \"550e8400-e29b-41d4-a716-446655440000\" & _status != 0", [
            "Literal.IDENT(id)", "Symbol.Infix(==)", "Literal.STRING", // 假设 UUID 扫为字符串或专门识别
            "Symbol.Infix(&)", "Literal.IDENT(_status)", "Symbol.Infix(!=)", "Literal.INT"
        ]),
        
        // 5. 极端紧凑的数组嵌套
        ("[[1,2],[3,4]][0][1]!!", [
            "Punctuator.SQUARE_L", "Punctuator.SQUARE_L", "Literal.INT", "Delimiter.COMMA", "Literal.INT", "Punctuator.SQUARE_R", "Delimiter.COMMA",
            "Punctuator.SQUARE_L", "Literal.INT", "Delimiter.COMMA", "Literal.INT", "Punctuator.SQUARE_R", "Punctuator.SQUARE_R",
            "Punctuator.SQUARE_L", "Literal.INT", "Punctuator.SQUARE_R", "Punctuator.SQUARE_L", "Literal.INT", "Punctuator.SQUARE_R",
            "Symbol.F_CAST", "Symbol.F_CAST"
        ])
    ])
    func testMultiTypeMashup(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "综合测试解析错误: \(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 2: 物理布局地狱 (Physical Layout Hell)
    // 涵盖：各种非法/奇异的空格、换行、连写
    @Test("物理布局压力测试", arguments: [
        // 1. 换行符作为分隔
        ("a\n+\nb", ["Literal.IDENT(a)", "Symbol.Infix(+)", "Literal.IDENT(b)"]),
        
        // 2. 紧凑的二元运算与前缀号 (1+-1)
        ("1+-1", ["Literal.INT", "Symbol.Infix(+)", "Symbol.Infix(-)", "Literal.INT"]),
        ("1 - -1", ["Literal.INT", "Symbol.Infix(-)", "Symbol.Prefix(-)", "Literal.INT"]),
        
        // 3. 连续的分隔符 (,,,)
        (",,,", ["Delimiter.COMMA", "Delimiter.COMMA", "Delimiter.COMMA"]),
        
        // 4. 符号与括号无间隙结合
        ("!(!a!!)", [
            "Symbol.NOT", "Punctuator.PAREN_L",
            "Symbol.NOT", "Literal.IDENT(a)", "Symbol.F_CAST", "Symbol.F_CAST",
            "Punctuator.PAREN_R"
        ]),
        
        // 5. 标识符紧贴字符串
        ("id==\"name\"", ["Literal.IDENT(id)", "Symbol.Infix(==)", "Literal.STRING"]),
        
        // 6. 三目运算符
        ("a ? b : c", ["Literal.IDENT(a)", "Symbol.TERNARY_QUEST", "Literal.IDENT(b)", "Symbol.TERNARY_COLON", "Literal.IDENT(c)"]),
        
        // 7. 复杂的点号与可选链
        ("a?.b.c?.d", [
            "Literal.IDENT(a)", "Symbol.OP_CHAIN", "Delimiter.DOT", "Literal.IDENT(b)",
            "Delimiter.DOT", "Literal.IDENT(c)", "Symbol.OP_CHAIN", "Delimiter.DOT", "Literal.IDENT(d)"
        ])
    ])
    func testLayoutHell(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "综合测试解析错误: \(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }

    // MARK: - 专项 3: 数据清洗与类型转换模拟
    @Test("数据转换 DSL 模拟", arguments: [
        // 模拟 value.asInteger() + 10
        ("value.asInteger() + 10", [
            "Literal.IDENT(value)", "Delimiter.DOT", "Literal.IDENT(asInteger)",
            "Punctuator.PAREN_L", "Punctuator.PAREN_R", "Symbol.Infix(+)", "Literal.INT"
        ]),
        // 模拟日期计算：'2026-01-01'.toDate() > nil
        ("\"2026-01-01\".toDate() > nil", [
            "Literal.STRING", "Delimiter.DOT", "Literal.IDENT(toDate)",
            "Punctuator.PAREN_L", "Punctuator.PAREN_R", "Symbol.Infix(>)", "Keyword.NULL"
        ])
    ])
    func testDataConversion(source: String, expectedTypes: [String]) {
        let result = Censor.Lexer(source: source).scanTokens()
        guard !result.hasErrors else {
            #expect(Bool(false), "综合测试解析错误: \(result)")
            return
        }
        let actualTypes = result.tokens.filter { $0.content.description != "EOF" }.map { $0.content.description }
        #expect(actualTypes == expectedTypes)
    }
}
