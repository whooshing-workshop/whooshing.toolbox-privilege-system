import Testing
import Foundation
@testable import Censor

@Suite("Parser 测试")
struct ParserTesting {
    @Test func dd() async throws {
        let source = "clwang.info.name.srt(\"hello\", 34)==\"Wang chenlin\"+[1,2,3]\n+ 1+(3-5)==10+10.2"
        let result = Censor.Lexer(source: source).scanTokens()
        #expect(!result.hasErrors)
        print(result)
//        let r = Censor.Parser(tokens: result.tokens, source: source).parse()
//        print(r.ast)
//        r.diagnostics.map { print($0.prettyDescription(in: source)) }
    }
}
