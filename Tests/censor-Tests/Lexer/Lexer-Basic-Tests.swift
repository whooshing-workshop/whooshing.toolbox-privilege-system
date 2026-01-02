import Testing
import Foundation
@testable import Censor

@Suite("Lexer 核心逻辑测试")
struct LexerTests {
    // MARK: - 1. 基础字面量测试
    @Test("基本类型识别", arguments: [
        ("123", "Literal.INT"),
        ("123.45", "Literal.DECIMAL"),
        ("'2025-01-01T10:00:00Z'", "Literal.DATE"),
        ("\"Hello Lexer\"", "Literal.STRING"),
        ("true", "Literal.BOOL")
    ])
    func testBaseLiterals(input: String, expectedType: String) {
        let result = Censor.Compiler.Lexer(source: input).scanTokens()
        #expect(result.tokens.count >= 1)
        let firstToken = result.tokens[0]
        #expect(firstToken.type.description == expectedType)
    }

    // MARK: - 2. 物理环境 (Prefix/Postfix/Infix) 专项测试
    @Suite("运算符缀位测试")
    struct OperatorContextTests {
        
        @Test("Logs")
        func logs() {
            print(Censor.Compiler.TrieNode.root)
        }
        
        @Test("感叹号身份识别: 前缀 vs 后缀")
        func testExclamationMark() {
            // 前缀：左虚(行首)右实
            let prefixResult = Censor.Compiler.Lexer(source: "!flag").scanTokens()
            print(prefixResult)
            #expect(prefixResult.tokens[0].type.description == "Symbol.NOT")
            
            // 后缀：左实右虚(行尾)
            let postfixResult = Censor.Compiler.Lexer(source: "flag!").scanTokens()
            #expect(postfixResult.tokens[1].type.description == "Symbol.F_CAST")
        }

        @Test("加号对称性: 中缀识别")
        func testAdditionInfix() {
            let result1 = Censor.Compiler.Lexer(source: "a + b").scanTokens()
            #expect(result1.tokens[1].type.description == "Symbol.Infix(+)")
            
            let result2 = Censor.Compiler.Lexer(source: "a+b").scanTokens()
            #expect(result2.tokens[1].type.description == "Symbol.Infix(+)")
        }

        @Test("Swift 风格不对称报错案例: (1+4) -1")
        func testAsymmetricOperator() {
            let result = Censor.Compiler.Lexer(source: "(1+4) -1").scanTokens()
            
            let minusToken = result.tokens[5] // 索引5应该是 '-'
            #expect(minusToken.type.description == "Symbol.Prefix(-)")
        }
    }

    // MARK: - 3. 复杂标点环境测试
    @Test("嵌套括号与紧凑符号: 1+(3-[4])")
    func testComplexBrackets() {
        let source = "1+(3-[4])"
        let result = Censor.Compiler.Lexer(source: source).scanTokens()
        
        #expect(!result.hasErrors)
    }

    // MARK: - 4. 字符串与操作数测试
    @Test("字符串连接识别")
    func testStringConcatenation() {
        let source = "\"str\"+123"
        let result = Censor.Compiler.Lexer(source: source).scanTokens()
        
        #expect(!result.hasErrors)
        #expect(result.tokens[1].type.description == "Symbol.Infix(+)")
    }

    // MARK: - 5. 错误处理测试
    @Test("非法字符识别")
    func testInvalidCharacter() {
        let source = "a # b"
        let result = Censor.Compiler.Lexer(source: source).scanTokens()
        #expect(result.hasErrors)
        #expect(result.diagnostics.first?.message.contains("非预期的字符") == true)
    }
    
    @Test("测试关键字识别")
    func testKeyword() {
        let result = Censor.Compiler.Lexer(source: "IN asdfas nil").scanTokens()
        print(result)
    }
}
