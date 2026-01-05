import Testing
@testable import Censor

@Suite("Parser: 集成场景测试")
struct ParserIntegrationTests {

    @Test("真实场景: 用户策略 (原 ParserVerification 案例)")
    func testRealWorldPolicy() {
        let exprSource = """
        clwang.info.name.srt("hello", 34) == "Wang chenlin" + [1, 2, 3]
        + 1 + (3 - 5) == 10 + 10.2
        """
        
        ParserTestHelpers.assertAST(exprSource, contains: [
            "Symbol.Infix(==)",
            "Symbol.Infix(.)", "Global(clwang)", "Property(info)", "Property(name)",
            "Function(srt)", "Value(hello)", "Value(34)",
            "Symbol.Infix(==)", "Value(Wang chenlin)", "Symbol.Infix(+)", "Array", "Value(1)", "Value(2)", "Value(3)",
            "Symbol.Infix(+)", "Value(1)", "Symbol.Infix(-)", "Value(3)", "Value(5)",
            "Symbol.Infix(==)", "Value(10)", "Value(10.2)"
        ])
        
        let ruleSource = """
        IN User {
           serverModule.name > 18
        }
        """
        
        ParserTestHelpers.assertAST(ruleSource, contains: [
            "Rule(IN)", "Global(User)",
            "Symbol.Infix(>)", "Global(serverModule)", "Property(name)", "Value(18)"
        ])
    }
    
    @Test("深度括号嵌套")
    func testDeepNesting() {
        ParserTestHelpers.assertAST("((1))", contains: ["Value(1)"])
    }
    
    @Test("链式比较 (非结合性检查)")
    func testComparisonChaining() {
        // 假设 < 是 infix, 且左结合
        ParserTestHelpers.assertAST("a < b < c", contains: ["Symbol.Infix(<)", "Global(a)", "Global(b)", "Global(c)"])
    }
    
    @Test("Kitchen Sink: 综合压力测试")
    func testKitchenSink() {
        // 包含深嵌套、混合类型、复杂 IN 规则的大型表达式
        let src = """
        IN System.Config {
            enabled == true & (
                server.load > 80 |
                admin.override.active != false
            ) & verify(
                [1, 2, 3 + 4], 
                user.role.contains("root")
            )
        }
        """
        
        ParserTestHelpers.assertAST(src, contains: [
            "Rule(IN)", "Symbol.Infix(.)", "Global(System)", "Property(Config)",
            "Symbol.Infix(&)",
            "Symbol.Infix(==)", "Global(enabled)", "Value(true)",
            "Symbol.Infix(|)",
            "Symbol.Infix(>)", "Symbol.Infix(.)", "Global(server)", "Property(load)", "Value(80)",
            "Symbol.Infix(!=)", "Symbol.Infix(.)", "Symbol.Infix(.)", "Global(admin)", "Property(override)", "Property(active)", "Value(false)",
            "Function(verify)",
            "Array", "Symbol.Infix(+)", "Value(3)", "Value(4)",
            "Function(contains)", "Symbol.Infix(.)", "Global(user)", "Property(role)", "Value(root)"
        ])
    }
}
