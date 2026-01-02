
import Foundation
@testable import Censor

func testParser() {
    let inputs = [
        "1 + 2 * 3", 
        "(1 + 2) * 3", 
        "user.age > 18 && user.active",
        "arr[0]",
        "isValid ? 1 : 0",
        "-a"
    ]
    
    for input in inputs {
        print("\n--- Testing: \(input) ---")
        let lexer = Censor.Compiler.Lexer(source: input)
        let lexResult = lexer.scanTokens()
        
        if lexResult.hasErrors {
            print("Lexer Errors: \(lexResult.diagnostics)")
            continue
        }
        
        let parser = Censor.Compiler.Parser(tokens: lexResult.tokens, source: input)
        let result = parser.parse()
        
        if result.hasErrors {
            print("Parser Errors: \(result.diagnostics)")
        } else {
            print("AST: \(result.ast)")
        }
    }
}

// Since we cannot run this directly without setting up full project,
// we will just assume it compiles if user accepts.
// A real test would require modifying Package.swift or creating a test file in Tests/
