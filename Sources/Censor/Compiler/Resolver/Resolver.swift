extension Censor {
    class Resolver {
        private let source: String
        private let globals: [String: any TypeDeclare] = [:]
        
        private var ast: AST
        private var errors: [Censor.Error] = []
        
        private var diagnostics: [Censor.Error] = []
        
        init(ast: AST, source: String) {
            self.ast = ast
            self.source = source
        }
        
        func resolve() -> Result {
//            resolve(ast: ast)
            
            return Result(content: (ast, []), diagnostics: errors, source: source)
        }
    }
}

private extension Censor.Resolver {
    func reportError(_ message: String, node: Censor.AST) {
        let errorRange = node.range
        
        let error = Censor.Error(
            kind: .semantic,
            range: errorRange,
            message: message,
            snippet: nil
        )
        errors.append(error)
    }
}

private extension Censor.Resolver {
    func resolve(ast: Censor.AST) -> (any Censor.TypeDeclare)? {
        nil
//        switch ast.content {
//        case .value(let variable): return variable.type
//        case .trueType(let string):
//            guard let t = Censor.BasicType(rawValue: string)?.realType else {
//                reportError("无法解析类型 \(string)", node: ast)
//                return nil
//            }
//            
//            return t == Censor.NullType.self ? Censor.Null : Censor.TrueType(real: t)
//        case .rule(let define, let contents):
//            precondition(contents.count == define.declare.argument.count, "rule 的定义出错")
//            
//            guard
//                let cs = (contents.map { resolve(ast: $0) }) as? [any Censor.TypeDeclare]
//            else {
//                return nil
//            }
//            
//            for (i, (_, t, def)) in define.declare.argument.enumerated() {
//                guard cs[i] == t else {
//                    reportError("预期为 \(type(of: t).name)，却得到 \(type(of: cs[i]).name)", node: contents[i])
//                    return nil
//                }
//            }
//            
//            return define.declare.returns()
//        case .global(let string):
//            guard let g = globals[string] else {
//                reportError("未知的变量 \(string)", node: ast)
//                return nil
//            }
//            
//            return g
//            
//        case .function(let string, let args):
//            
//        case .array(let array):
//            
//        case .arraySelector(let index, let at):
//            
//        case .prefix(let `operator`, let right):
//            
//        case .postfix(let `operator`, let left):
//            
//        case .infix(let `operator`, let left, let right):
//            
//        }
    }
}

extension Censor.Resolver {
    public struct Result {
        public let content: (Censor.AST, [Censor.Map])?
        public let diagnostics: [any Swift.Error]
        public let source: String
        
        public var hasErrors: Bool {
            !diagnostics.isEmpty
        }
    }
}
