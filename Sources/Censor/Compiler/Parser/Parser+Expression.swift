import Foundation
import ErrorHandle

extension Censor.Parser {
    
    // MARK: - Pratt 解析核心
    
    func parseExpression(precedence: Censor.Symbol.AnyPrecedence = Censor.Symbol.Precedence.Lowest().any) -> Censor.AST? {
        let token = peek()
        
        // 1. 前缀表达式
        guard let prefixRule = getPrefixRule(for: token.content) else {
            report(error: "无法解析符号: \(token.content)")
            return nil
        }
        
        guard var left = prefixRule() else { return nil }
        
        // 2. 中缀 / 后缀表达式
        while getPrecedence(for: peek()).bindsTighter(than: precedence) {
            guard let infixRule = getInfixRule(for: peek()) else {
                return left
            }
            guard let next = infixRule(left) else {
                return nil
            }
            left = next
        }
        
        return left
    }
    
    // MARK: - 优先级
    
    func getPrecedence(for token: Token) -> Censor.Symbol.AnyPrecedence {
        if let op = token.content as? Censor.Symbol.Operator {
            return op.precedence
        }
        // 特殊处理: Punctuator.Paren.Left '(' 作为函数调用，应当有极高优先级
        if isCall(token) { return Censor.Symbol.Precedence.Postfix().any }
        
        // 数组下标 '['
        if isSubscript(token) { return Censor.Symbol.Precedence.Postfix().any }
        
        return Censor.Symbol.Precedence.Lowest().any
    }
    
    private func isCall(_ token: Token) -> Bool {
        // Punctuator.Paren.Left is call if infix
        guard let p = token.content as? Censor.Symbol.Paren.Left else { return false }
        return p.lexeme == "("
    }

    private func isSubscript(_ token: Token) -> Bool {
        guard let p = token.content as? Censor.Symbol.Square.Left else { return false }
        return p.lexeme == "["
    }

    // MARK: - 规则表
    
    typealias PrefixRule = () -> Censor.AST?
    typealias InfixRule = (Censor.AST) -> Censor.AST?
    
    func getPrefixRule(for symbol: any Censor.TokenUnit) -> PrefixRule? {
        // 字面量
        if symbol is Censor.Literal {
            return parseLiteral
        }
        
        // 前缀运算符
        if let _ = symbol as? any Censor.Symbol.Prefix {
            return { self.parsePrefixOperator() }
        }
        
        // 分组 '('
        if symbol is Censor.Symbol.Paren.Left {
            return parseGrouping
        }
        
        // 数组字面量 '[' (前缀)
        if symbol is Censor.Symbol.Square.Left {
            return parseArray
        }

        return nil
    }
    
    func getInfixRule(for token: Token) -> InfixRule? {
        let symbol = token.content
        
        // 中缀运算符（二元）
        if let _ = symbol as? any Censor.Symbol.Infix {
            return { left in self.parseInfixOperator(left: left) }
        }
        
        // 后缀运算符
        if let _ = symbol as? any Censor.Symbol.Postfix {
            return { left in self.parsePostfixOperator(left: left) }
        }
        
        // 函数调用 '('
        if isCall(token) {
            return { left in self.parseCall(left: left) }
        }
        
        // 数组下标 '['
        if isSubscript(token) {
            return { left in self.parseSubscript(left: left) }
        }
        
        return nil
    }
    
    // MARK: - 解析函数
    
    private func parseLiteral() -> Censor.AST? {
        let token = advance()
        let range = token.range
        guard let literal = token.content as? Censor.Literal else { return nil }
        
        switch literal {
        case .string(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .character(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .integer(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .decimal(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .date(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .uuid(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .bool(let v): return .init(content: .value(Censor.AnyVariable(v)), range: range)
        case .trueType(let v): return .init(content: .trueType(v.value ?? ""), range: range)
            
        case .identifier(let name):
            // 检查是否匹配基础类型
            if Censor.BasicType(rawValue: name) != nil {
                return .init(content: .trueType(name), range: range)
            }
            return .init(content: .global(name), range: range)
        }
    }
    
    private func parseGrouping() -> Censor.AST? {
        let token = advance() // (
        let start = token.range.start
        
        // FIXME: If parseExpression() returns nil (error), we can't form a valid range easily unless we just use '(' range or consume until ')'.
        // But parseExpression handles its own errors. If it returns nil, we return nil.
        guard let expr = parseExpression() else { return nil }
        
        let endToken = consume(lexeme: ")", message: "预期在表达式后输入 ')'") 
        let end = endToken?.range.end ?? expr.range.end // If consume fails (and returns nil), fallback to expr end
        
        // The AST structure usually doesn't wrap grouping, just returns the inner expression.
        // But if we return `expr`, we lose the parentheses information in terms of range (the returned AST has the range of the inner expr).
        // Since `grouping` isn't an AST node itself in the enum (it's structural), we just return `expr`.
        // However, if we wanted to reflect the grouping range, we might need a Grouping node or just accept that the AST is simplified.
        // Current implementation: `return expr`. So range update here is moot unless we wrap it.
        // We will stick to returning `expr` as per existing logic.
        return expr
    }
    
    private func parseArray() -> Censor.AST? {
        let token = advance() // [
        let start = token.range.start
        
        var elements: [Censor.AST] = []
        if !check(lexeme: "]") {
            repeat {
                if let elem = parseExpression() {
                    elements.append(elem)
                }
            } while match(lexeme: ",")
        }
        
        let endToken = consume(lexeme: "]", message: "预期在数组元素后输入 ']'")
        let end = endToken?.range.end ?? token.range.end
        
        return .init(content: .array(elements), range: .init(start: start, end: end))
    }
    
    private func parsePrefixOperator() -> Censor.AST? {
        let token = advance()
        let start = token.range.start
        guard let opStruct = token.content as? any Censor.Symbol.Operator else { return nil }
        guard let enumCase = findPrefixEnum(for: opStruct) else {
            diagnostics.append(.init(kind: .syntactic, range: token.range, message: "未知的前缀运算符", snippet: nil))
            return nil
        }
        
        let precedence = opStruct.precedence
        guard let right = parseExpression(precedence: precedence) else { return nil }
        
        // Range: op start -> right end
        return .init(content: .prefix(operator: enumCase, right: right), range: .init(start: start, end: right.range.end))
    }
    
    private func parsePostfixOperator(left: Censor.AST) -> Censor.AST? {
        let token = advance()
        let end = token.range.end
        guard let opStruct = token.content as? any Censor.Symbol.Operator else { return nil }
        guard let enumCase = findPostfixEnum(for: opStruct) else { return nil }
        
        // Range: left start -> op end
        return .init(content: .postfix(operator: enumCase, left: left), range: .init(start: left.range.start, end: end))
    }
    
    private func parseInfixOperator(left: Censor.AST) -> Censor.AST? {
        let token = advance()
        // token is the operator.
        // We need left start -> right end.
        
        guard let opStruct = token.content as? any Censor.Symbol.Operator else { return nil }
        
        let precedence = opStruct.precedence
        guard let right = parseExpression(precedence: precedence) else { return nil }
        
        let range = Censor.SourceRange(start: left.range.start, end: right.range.end)
        
        // 特殊处理 Dot (.) 运算符
        if opStruct is Censor.Symbol.Dot {
            if case .global(let name) = right.content {
                // right was parsed as global(name), but in dot notation it is a property.
                // We create a new property node using right's range.
                let propertyNode = Censor.AST(content: .property(name), range: right.range)
                
                return .init(content: .infix(operator: .dot, left: left, right: propertyNode), range: range)
            }
        }
        
        guard let enumCase = findInfixEnum(for: opStruct) else { return nil }
        return .init(content: .infix(operator: enumCase, left: left, right: right), range: range)
    }
    
    private func parseCall(left: Censor.AST) -> Censor.AST? {
        advance() // (
        // Start: left.range.start
        
        var args: [Censor.AST] = []
        if !check(lexeme: ")") {
            repeat {
                if let arg = parseExpression() {
                    args.append(arg)
                }
            } while match(lexeme: ",")
        }
        let endToken = consume(lexeme: ")", message: "预期在参数列表后输入 ')'")
        let end = endToken?.range.end ?? left.range.end // fallback
        let range = Censor.SourceRange(start: left.range.start, end: end)
        
        switch left.content {
        case .global(let name):
            return .init(content: .function(name, args: args), range: range)
        case .property(let name):
            return .init(content: .function(name, args: args), range: range)
        case .infix(let op, let l, let r):
            if op == .dot {
                // l.r(...) -> l.func(...)
                if case .property(let name) = r.content {
                    // Update the property node to a function node, using the FULL range (l.start -> ) end).
                    // Wait, the infix node covers l...r. The call covers l...r...().
                    // New structure: infix(., l, function(name, args)) ?? 
                    // No, existing logic was infix(., l, right: .function(name, args)). 
                    // The 'right' node of the infix becomes the function call.
                    // The function call's range should be 'r.start' -> ')'.end'.
                    // The infix node's range should be 'l.start' -> ')'.end'.
                    
                    let funcRange = Censor.SourceRange(start: r.range.start, end: end)
                    let funcNode = Censor.AST(content: .function(name, args: args), range: funcRange)
                    
                    return .init(content: .infix(operator: .dot, left: l, right: funcNode), range: range)
                }
            }
            return .init(content: .function("", args: args), range: range)
        default:
             return .init(content: .function("", args: args), range: range)
        }
    }
    
    private func parseSubscript(left: Censor.AST) -> Censor.AST? {
        advance() // [
        let start = left.range.start
        
        guard let indexExpr = parseExpression(), 
              case .value(let v) = indexExpr.content else {
              
              report(error: "数组下标必须是整数常量")
              return nil
        }
        
        var index = 0
        if case .integer(let i) = v.storingValue, let distinctI = i {
            index = Int(distinctI)
        } else {
             report(error: "数组下标整数提取失败")
             return nil
        }

        let endToken = consume(lexeme: "]", message: "预期在下标后输入 ']'")
        let end = endToken?.range.end ?? indexExpr.range.end
        
        return .init(content: .arraySelector(index: index, at: left), range: .init(start: start, end: end))
    }

    // MARK: - 辅助方法：枚举映射
    
    private func findPrefixEnum(for op: any Censor.Symbol.Operator) -> Censor.Symbol.PrefixOperator? {
        for c in Censor.Symbol.PrefixOperator.allCases {
            if c.operator.lexeme == op.lexeme { return c }
        }
        return nil
    }
    
    private func findPostfixEnum(for op: any Censor.Symbol.Operator) -> Censor.Symbol.PostfixOperator? {
        for c in Censor.Symbol.PostfixOperator.allCases {
            if c.operator.lexeme == op.lexeme { return c }
        }
        return nil
    }

    private func findInfixEnum(for op: any Censor.Symbol.Operator) -> Censor.Symbol.InfixOperator? {
        for c in Censor.Symbol.InfixOperator.allCases {
            if c.operator.lexeme == op.lexeme { return c }
        }
        return nil
    }

}
