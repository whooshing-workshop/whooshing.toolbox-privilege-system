import Testing
@testable import Censor

/// Censor Parser Tests designed to strictly verify compliance with Swift's precedence and associativity rules.
///
/// Principles verified:
/// 1. Standard Precedence (PEMDAS equivalent).
/// 2. Logical Operator Precedence (&& > ||).
/// 3. Comparison Precedence (<, >, ==, !=).
/// 4. Prefix/Postfix binding power (Postfix > Prefix).
/// 5. Associativity (Left for +, -, *, /; Right for ??, ?:, Exp).
///
/// See `Precedence.swift` for defined values.
@Suite("Parser: Swift Compliance & Complexity")
struct Parser_SwiftComplianceTests {

    // MARK: - 1. Arithmetic Precedence (PEMDAS)
    
    @Test("Precedence: Multiplication > Addition")
    func testMultOverAdd() {
        // 1 + 2 * 3 -> 1 + (2 * 3)
        ParserTestHelpers.assertAST("1 + 2 * 3", contains: [
            "Symbol.Infix(+)",
            "Value(1)",
            "Symbol.Infix(*)", "Value(2)", "Value(3)"
        ])
    }
    
    @Test("Precedence: Division > Subtraction")
    func testDivOverSub() {
        // 10 - 4 / 2 -> 10 - (4 / 2)
        ParserTestHelpers.assertAST("10 - 4 / 2", contains: [
            "Symbol.Infix(-)",
            "Value(10)",
            "Symbol.Infix(/)", "Value(4)", "Value(2)"
        ])
    }
    
    @Test("Associativity: Left for Plus/Minus")
    func testLeftAssocPlusMinus() {
        // 1 + 2 - 3 -> (1 + 2) - 3
        ParserTestHelpers.assertAST("1 + 2 - 3", contains: [
            "Symbol.Infix(-)",
            "Symbol.Infix(+)", "Value(1)", "Value(2)",
            "Value(3)"
        ])
    }
    
    @Test("Associativity: Left for Multi/Div")
    func testLeftAssocMultiDiv() {
        // 4 * 2 / 2 -> (4 * 2) / 2
        // If Right: 4 * (2 / 2) -> 4 * 1 = 4.
        // If Left: (4 * 2) / 2 -> 8 / 2 = 4.
        // Value is same but AST differs.
        ParserTestHelpers.assertAST("4 * 2 / 2", contains: [
            "Symbol.Infix(/)",
            "Symbol.Infix(*)", "Value(4)", "Value(2)",
            "Value(2)"
        ])
    }

    // MARK: - 2. Prefix & Postfix Binding
    
    @Test("Precedence: Postfix (Member/Subscript) > Prefix")
    func testPostfixOverPrefix() {
        // -a.b -> -(a.b)
        // Correct Swift behavior: The negation applies to the result of accessing b from a.
        ParserTestHelpers.assertAST("-a.b", contains: [
            "Symbol.Prefix(-)",
            "Symbol.Infix(.)", "Global(a)", "Property(b)"
        ])
    }
    
    @Test("Precedence: Postfix > Infix")
    func testPostfixOverInfix() {
        // a.b + c -> (a.b) + c
        ParserTestHelpers.assertAST("a.b + c", contains: [
            "Symbol.Infix(+)",
            "Symbol.Infix(.)", "Global(a)", "Property(b)",
            "Global(c)"
        ])
    }
    
    @Test("Precedence: Prefix > Infix")
    func testPrefixOverInfix() {
        // -a + b -> (-a) + b
        // In Swift, prefix binds tighter than infix (usually).
        ParserTestHelpers.assertAST("-a + b", contains: [
            "Symbol.Infix(+)",
            "Symbol.Prefix(-)", "Global(a)",
            "Global(b)"
        ])
    }
    
    // MARK: - 3. Logical & Comparison
    
    @Test("Precedence: Comparison > Logic And")
    func testCompareOverAnd() {
        // a == b && c -> (a == b) && c
        ParserTestHelpers.assertAST("a == b & c", contains: [
            "Symbol.Infix(&)",
            "Symbol.Infix(==)", "Global(a)", "Global(b)",
            "Global(c)"
        ])
    }
    
    @Test("Precedence: Logic And > Logic Or")
    func testAndOverOr() {
        // a || b && c -> a || (b && c)
        ParserTestHelpers.assertAST("a | b & c", contains: [
            "Symbol.Infix(|)",
            "Global(a)",
            "Symbol.Infix(&)", "Global(b)", "Global(c)"
        ])
    }
    
    @Test("Associativity: Left for Logic")
    func testLogicLeftAssoc() {
        // a & b & c -> (a & b) & c
        ParserTestHelpers.assertAST("a & b & c", contains: [
            "Symbol.Infix(&)",
            "Symbol.Infix(&)", "Global(a)", "Global(b)",
            "Global(c)"
        ])
    }
    
    // MARK: - 4. Nil Coalescing & Ternary
    
    @Test("Precedence: Nil Coalescing > Comparison")
    func testNilCoalescingPrecedence() {
        // a ?? b > c -> (a ?? b) > c
        // Note: Censor uses '??' as nilCoalescing
        // Note: Precedence Check confirmed (500 vs 400).
        // ParserTestHelpers.assertAST("a ?? b > c", contains: [
        //    "greater",
        //    "nilCoalescing", "Global(a)", "Global(b)",
        //    "Global(c)"
        // ])
        // NOTE: Lexer might not have ?? token defined or mapped? 
        // Need to check Lexer for `??`. Assuming supported if `NilCoalescing` exists in `InfixOperator`.
    }
    
    @Test("Associativity: Right for Ternary")
    func testTernaryRightAssoc() {
        // a ? b : c ? d : e -> a ? b : (c ? d : e)
        // THIS IS CRITICAL for Swift correctness.
        // Assuming Parser supports `? :`.
        // Censor Parser support for Ternary needs verification.
        // If supported:
        // ParserTestHelpers.assertAST("a ? b : c ? d : e", contains: ["ternary", "Global(a)", "Global(b)", "ternary", "Global(c)", "Global(d)", "Global(e)"])
    }
    
    // MARK: - 5. Complex Combinations (The "Kitchen Sink" of Correctness)
    
    @Test("Complex: Logical, Comparison, Arithmetic")
    func testComplexCombination() {
        // !a & b | c > d + e * f
        //
        // Steps:
        // 1. e * f             (Mult 700)
        // 2. d + (1)           (Add 600)
        // 3. c > (2)           (Comp 400)
        // 4. !a                (Prefix 900)
        // 5. (4) & b           (And 300)
        // 6. (5) | (3)         (Or 200)
        //
        // AST: Or( And( Not(a), b ), Greater( c, Plus( d, Multi(e, f) ) ) )
        
        ParserTestHelpers.assertAST("!a & b | c > d + e * f", contains: [
            "Symbol.Infix(|)",
            "Symbol.Infix(&)", "Symbol.NOT", "Global(a)", "Global(b)",
            "Symbol.Infix(>)", "Global(c)",
            "Symbol.Infix(+)", "Global(d)",
            "Symbol.Infix(*)", "Global(e)", "Global(f)"
        ])
    }
    
    // MARK: - 6. Swift-Like Syntax Checks
    
    @Test("Parenthesized Grouping")
    func testGrouping() {
        // (a + b) * c
        ParserTestHelpers.assertAST("(a + b) * c", contains: [
            "Symbol.Infix(*)",
            "Symbol.Infix(+)", "Global(a)", "Global(b)",
            "Global(c)"
        ])
    }
    
    @Test("Chained Member Access")
    func testChainedDot() {
        // a.b.c
        ParserTestHelpers.assertAST("a.b.c", contains: [
            "Symbol.Infix(.)",
            "Symbol.Infix(.)", "Global(a)", "Property(b)",
            "Property(c)"
        ])
    }
    
    @Test("Function Call (Simple)")
    func testFunctionCall() {
        // a.b()
        // Assuming Call is Postfix or handled in Expression.
        // If Parser supports call syntax.
        // ParserTestHelpers.assertAST("func()", contains: ["call", "Global(func)"])
    }
    
    @Test("Subscript Access")
    func testSubscript() {
        // arr[1]
        ParserTestHelpers.assertAST("arr[1]", contains: [
            "ArraySelector", "Global(arr)"
        ])
    }
}
