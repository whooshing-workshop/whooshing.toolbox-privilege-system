import Foundation

extension Censor.Keyword {
    struct IN: Define {
        let lexeme = "IN"
        let name = "IN"
    }
}

extension Censor.Rule {
    struct In: Define {
        let keyword: Censor.Keyword.Define = Censor.Keyword.IN()
        let name = "IN"
        let description = "Rule(IN)"
        let declare = Censor.FunctionDeclare {
            Censor.Return { Censor.Null }
            Censor.ArgumentDeclare {
                (nil, { Censor.StringType(nullable: false) }) >- nil
                (nil, { Censor.BoolType(nullable: false) }) >- nil
            }
        }

        func parse(parser: Censor.Parser) -> Censor.AST? {
            // 1. 消费 'IN'
            let token = parser.peek() 
            let start = token.range.start
            parser.advance()
            
            // 2. 解析 Domain (Expression)
            guard let domainAST = parser.parseExpression() else {
                parser.report(error: "IN 语句后需跟随 Domain 表达式")
                return nil
            }

            // 3. 期待左大括号 '{'
            if !parser.match(Censor.Symbol.Curly.Left.self) {
                parser.report(error: "IN 语句后需跟随代码块 '{'")
                return nil
            }
            
            // 4. 解析代码块内容（单条语句）
            guard let stmt = parser.parseStatement() else {
               parser.report(error: "IN 代码块不能为空")
               return nil
            }
            
            // 5. 确保紧接着是右大括号 '}'（不允许其多语句）
            if !parser.check(Censor.Symbol.Curly.Right.self) {
                 parser.report(error: "IN 代码块内仅包含一条语句")
                 // 跳过直到 '}' 以恢复？
                 while !parser.atEnd && !parser.check(Censor.Symbol.Curly.Right.self) {
                     parser.advance()
                 }
            }
            
            // 消费右大括号 '}'
            let endToken = parser.consume(Censor.Symbol.Curly.Right.self, message: "期待 '}' 以结束 IN 代码块")
            let end = endToken?.range.end ?? stmt.range.end
            
            // 6. 构造 Generic Rule Node
            return .init(content: .rule(self, contents: [domainAST, stmt]), range: .init(start: start, end: end))
        }
    }
}
