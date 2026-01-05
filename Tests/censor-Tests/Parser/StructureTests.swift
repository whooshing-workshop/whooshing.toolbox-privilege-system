import Testing
@testable import Censor

@Suite("Parser: 结构与调用")
struct ParserStructureTests {

    // MARK: - 成员访问与函数调用
    @Test("成员访问与调用链路")
    func testMemberAndCall() {
        ParserTestHelpers.assertAST("user.name", contains: ["Symbol.Infix(.)", "Global(user)", "Property(name)"])
        ParserTestHelpers.assertAST("user.profile.age", contains: ["Symbol.Infix(.)", "Global(user)", "Property(profile)", "Property(age)"])
        
        ParserTestHelpers.assertAST("check()", contains: ["Function(check)"])
        ParserTestHelpers.assertAST("check(1, 2)", contains: ["Function(check)", "Value(1)", "Value(2)"])
        
        ParserTestHelpers.assertAST("user.check()", contains: ["Symbol.Infix(.)", "Global(user)", "Function(check)"])
        ParserTestHelpers.assertAST("user.profile.validate(true)", contains: ["Symbol.Infix(.)", "Global(user)", "Property(profile)", "Function(validate)", "Value(true)"])
    }

    // MARK: - 数组与下标
    @Test("数组与下标访问")
    func testArray() {
        ParserTestHelpers.assertAST("[1, 2, 3]", contains: ["Array", "Value(1)", "Value(2)", "Value(3)"])
        ParserTestHelpers.assertAST("list[0]", contains: ["ArraySelector", "Global(list)", "ArraySelector(0)"])
        
        // Complex chaining: matrix[0].value
        ParserTestHelpers.assertAST("matrix[0].value", contains: [
            "Symbol.Infix(.)",
            "ArraySelector(0)",
            "Global(matrix)",
            "Property(value)"
        ])
    }
    
    // MARK: - 复杂参数结构
    @Test("函数参数复杂结构")
    func testComplexArgs() {
        // sum([1+1, 2], x * y)
        ParserTestHelpers.assertAST("sum([1+1, 2], x * y)", contains: [
            "Function(sum)",
            "Array", "Symbol.Infix(+)", "Value(1)", "Value(2)",
            "Symbol.Infix(*)", "Global(x)", "Global(y)"
        ])
    }
    
    // MARK: - 深度结构混用
    @Test("深度结构混用测试")
    func testDeepStructure() {
        // 1. Array inside Function inside Member Access inside Array
        // [user.get([1])]
        ParserTestHelpers.assertAST("[user.get([1])]", contains: [
            "Array",
            "Symbol.Infix(.)",
            "Global(user)",
            "Function(get)",
            "Array", "Value(1)"
        ])
        
        // 2. Deep chained access
        // a.b.c.d.e
        ParserTestHelpers.assertAST("a.b.c.d.e", contains: [
            "Symbol.Infix(.)", "Symbol.Infix(.)", "Symbol.Infix(.)", "Symbol.Infix(.)",
            "Global(a)", "Property(b)", "Property(c)", "Property(d)", "Property(e)"
        ])
        
        // 3. Mixed Index and Call
        // list[0].func().prop[1]
        ParserTestHelpers.assertAST("list[0].func().prop[1]", contains: [
            "ArraySelector(1)",
            "Symbol.Infix(.)",
            "Symbol.Infix(.)",
            "ArraySelector(0)",
            "Global(list)",
            "Function(func)",
            "Property(prop)"
        ])
        
        // 4. Nested Arrays
        // [[1, 2], [3, 4]]
        ParserTestHelpers.assertAST("[[1, 2], [3, 4]]", contains: [
            "Array",
            "Array", "Value(1)", "Value(2)",
            "Array", "Value(3)", "Value(4)"
        ])
    }
}
