import Foundation
import ErrorHandle

extension Censor.Parser {
    
    // MARK: - Pratt 解析核心
    
    func parseExpression(precedence: Censor.Symbol.AnyPrecedence = Censor.Symbol.Precedence.Lowest().any) -> Censor.AST? {
        let token = peek().content
        
        // 1. 前缀表达式
        guard let prefixRule = getPrefixRule(for: token) else {
            report(error: "无法解析符号: \(token)")
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
        guard let literal = token.content as? Censor.Literal else { return nil }
        
        switch literal {
        case .string(let v): return .value(Censor.AnyVariable(v))
        case .character(let v): return .value(Censor.AnyVariable(v))
        case .integer(let v): return .value(Censor.AnyVariable(v))
        case .decimal(let v): return .value(Censor.AnyVariable(v))
        case .date(let v): return .value(Censor.AnyVariable(v))
        case .uuid(let v): return .value(Censor.AnyVariable(v))
        case .bool(let v): return .value(Censor.AnyVariable(v))
        case .trueType(let v): return .trueType(v.value ?? "") // Assuming RealType is String and value is relevant
            
        case .identifier(let name):
            // 检查是否匹配基础类型
            if Censor.BasicType(rawValue: name) != nil {
                return .trueType(name)
            }
            return .global(name) // Renamed from variable -> global in new AST
        }
    }
    
    private func parseGrouping() -> Censor.AST? {
        advance() // (
        let expr = parseExpression()
        consume(lexeme: ")", message: "预期在表达式后输入 ')'") // simplified: assume match can do string match if we implement it, or generic
        // In Parser+Extensions I implemented consume(lexeme, ...)
        return expr
    }
    
    private func parseArray() -> Censor.AST? {
        advance() // [
        var elements: [Censor.AST] = []
        if !check(lexeme: "]") {
            repeat {
                if let elem = parseExpression() {
                    elements.append(elem)
                }
            } while match(lexeme: ",")
        }
        consume(lexeme: "]", message: "预期在数组元素后输入 ']'")
        return .array(elements)
    }
    
    private func parsePrefixOperator() -> Censor.AST? {
        let token = advance()
        guard let opStruct = token.content as? any Censor.Symbol.Operator else { return nil }
        guard let enumCase = findPrefixEnum(for: opStruct) else {
            diagnostics.append(.init(kind: .syntactic, range: token.range, message: "未知的前缀运算符", snippet: nil))
            return nil
        }
        
        let precedence = opStruct.precedence
        guard let right = parseExpression(precedence: precedence) else { return nil }
        return .prefix(operator: enumCase, right: right)
    }
    
    private func parsePostfixOperator(left: Censor.AST) -> Censor.AST? {
        let token = advance()
        guard let opStruct = token.content as? any Censor.Symbol.Operator else { return nil }
        guard let enumCase = findPostfixEnum(for: opStruct) else { return nil }
        
        return .postfix(operator: enumCase, left: left)
    }
    
    private func parseInfixOperator(left: Censor.AST) -> Censor.AST? {
        let token = advance()
        guard let opStruct = token.content as? any Censor.Symbol.Operator else { return nil }
        
        // 处理 Dot 以映射属性（如果右侧是 Identifier）
        // 实际上，AST 需要 `infix(.dot, left, right)`. 
        // Dot 的 `right` 应当是 `.property(name)`.
        // 让我们先解析正常的右侧表达式。
        
        let precedence = opStruct.precedence
        guard let right = parseExpression(precedence: precedence) else { return nil }
        
        // 特殊处理 Dot (.) 运算符
        if opStruct is Censor.Symbol.Dot {
            // AST 转换: .dot(left, right) -> .infix(.dot, left, .property(name))
            if case .global(let name) = right {
                return .infix(operator: .dot, left: left, right: .property(name))
            }
            // 若 right 是 .function(name, args)，保留原样即可支持链式调用
        }
        
        // 普通中缀
        guard let enumCase = findInfixEnum(for: opStruct) else { return nil }
        return .infix(operator: enumCase, left: left, right: right)
    }
    
    private func parseCall(left: Censor.AST) -> Censor.AST? {
        advance() // (
        var args: [Censor.AST] = []
        if !check(lexeme: ")") {
            repeat {
                if let arg = parseExpression() {
                    args.append(arg)
                }
            } while match(lexeme: ",")
        }
        consume(lexeme: ")", message: "预期在参数列表后输入 ')'")
        
        // AST 转换逻辑:
        // 将 `variable(name)`, `property(name)` 或点号表达式右侧转换为 `function(name, args)`
        
        switch left {
        case .global(let name):
            return .function(name, args: args)
        case .property(let name):
            return .function(name, args: args)
        case .infix(let op, let l, let r):
            if op == .dot {
                // 递归转换右侧为函数调用
                if case .property(let name) = r {
                    return .infix(operator: .dot, left: l, right: .function(name, args: args))
                }
            }
            // 兜底: 匿名/复杂调用不支持，返回空名函数占位
            return .function("", args: args) 
        default:
             return .function("", args: args)
        }
    }
    
    private func parseSubscript(left: Censor.AST) -> Censor.AST? {
        advance() // [
        // AST `arraySelector(index: Int, at: Self)`
        // This requires index to be strictly Int literal.
        
        guard let indexExpr = parseExpression(), 
              case .value(let v) = indexExpr else {
              
              // Fallback logic inside check
              report(error: "数组下标必须是整数常量")
              return nil
        }
        
        // Extract int value
        var index = 0
        if case .integer(let i) = v.storingValue, let distinctI = i {
            index = Int(distinctI)
        } else {
             report(error: "数组下标整数提取失败")
             return nil
        }

        consume(lexeme: "]", message: "预期在下标后输入 ']'")
        
        return .arraySelector(index: index, at: left)
    }

    // MARK: - 辅助方法：枚举映射
    
    private func findPrefixEnum(for op: any Censor.Symbol.Operator) -> Censor.Symbol.PrefixOperator? {
        // 遍历所有用例并匹配 lexeme？
        // 符号定义 `==` 实现匹配 lexeme 和 type。
        // 我们可以检查相等性。
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
