import Testing
import ErrorHandle
import Foundation
@testable import Censor

@Suite("Censor.Lexer 测试集")
struct LexerTests {
    @Test()
    func testing() {
        print(Censor.Compiler.TrieNode.root)
        
        let exp = "+1.3+67.1 - [3,4,5] +[ 4 ]+ 1 == '2025-01-01T03:21:00Z'+123-'c'>=0"
        let lexer = Censor.Compiler.Lexer(source: exp)
        let result = lexer.scanTokens()
        
        print(result)
    }
}
