import Testing
@testable import Censor

@Suite("Parser: 规则定义 (IN)")
struct ParserRuleTests {

    // MARK: - IN 规则 (核心逻辑)
    @Test("IN 规则: 基础与复杂 Domain")
    func testInRule() {
        // 基础 IN rule
        ParserTestHelpers.assertAST("IN User { age >= 18 }", contains: [
            "Rule(IN)",
            "Global(User)",     // Domain
            "Symbol.Infix(>=)",       // Body
            "Global(age)",
            "Value(18)"
        ])
        
        // 复杂 Domain IN rule
        ParserTestHelpers.assertAST("IN server.module { status == 1 }", contains: [
            "Rule(IN)",
            "Symbol.Infix(.)",                // Domain is dot expression
            "Global(server)",
            "Property(module)",
            "Symbol.Infix(==)",              // Body
            "Global(status)"
        ])
    }
    
    @Test("IN 规则: 嵌套结构")
    func testNestedInRule() {
        // 嵌套 IN rule
        let nestedSource = """
        IN Global {
            IN SubDomain {
                valid == true
            }
        }
        """
        ParserTestHelpers.assertAST(nestedSource, contains: [
            "Rule(IN)", "Global(Global)",
            "Rule(IN)", "Global(SubDomain)",
            "Symbol.Infix(==)", "Global(valid)"
        ])
    }
    
    // MARK: - 复杂 IN 场景
    @Test("IN 规则: 复杂 Domain 与表达式")
    func testComplexRule() {
        // 1. Domain is deep member access
        // IN corp.hr.region.china { ... }
        ParserTestHelpers.assertAST("IN corp.hr.region.china { allow == true }", contains: [
            "Rule(IN)",
            "Symbol.Infix(.)", "Symbol.Infix(.)", "Symbol.Infix(.)",
            "Global(corp)", "Property(hr)", "Property(region)", "Property(china)",
            "Symbol.Infix(==)"
        ])
        
        // 2. Body has complex logic
        // IN User { age > 18 & (vip == true | admin == true) }
        ParserTestHelpers.assertAST("IN User { age > 18 & (vip == true | admin == true) }", contains: [
            "Rule(IN)", "Global(User)",
            "Symbol.Infix(&)",
            "Symbol.Infix(>)", "Global(age)", "Value(18)",
            "Symbol.Infix(|)",
            "Symbol.Infix(==)", "Global(vip)", "Value(true)",
            "Symbol.Infix(==)", "Global(admin)", "Value(true)"
        ])
        
        // 3. Nested IN with complex body
        let src = """
        IN A {
            IN B {
                x + y > z
            }
        }
        """
        ParserTestHelpers.assertAST(src, contains: [
            "Rule(IN)", "Global(A)",
            "Rule(IN)", "Global(B)",
            "Symbol.Infix(>)",
            "Symbol.Infix(+)", "Global(x)", "Global(y)",
            "Global(z)"
        ])
    }
}
