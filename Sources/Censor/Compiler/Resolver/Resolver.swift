extension Censor {
    class Resolver {
        private let source: String
        private let globals: [any TypeDeclare] = []
        
        private var ast: AST
        private var current: AST
        private var errors: [Censor.Error] = []
        
        private var current = 0
        private var diagnostics: [Censor.Error] = []
        
        init(ast: AST, source: String) {
            self.ast = ast
            self.source = source
        }
        
        func resolve() -> Result {
            resolve(ast: ast)
            
            return Result(content: (ast, []), diagnostics: errors, source: source)
        }
    }
}

private extension Censor.Resolver {
    func reportError(_ message: String, start: Censor.SourceLocation, kind: Censor.Error.Kind = .semantic) {
        let errorRange = Censor.SourceRange(start: start, end: )
        
        let error = Censor.Error(
            kind: kind,
            range: errorRange,
            message: message,
            snippet: nil
        )
        errors.append(error)
        
        if !atEnd { _ = advance() }
    }
}

private extension Censor.Resolver {
    func resolve(ast: Censor.AST) -> any Censor.TypeDeclare {
        switch ast {
        case .value(let variable): return variable.type
        case .trueType(let string):
            Censor.TrueType(nullable: <#T##Bool#>, type: <#T##any Censor.TypeDeclare.Type#>)
        case .rule(let define, let contents):
            
        case .global(let string):
            
        case .property(let string):
            
        case .keyword(let define):
            
        case .function(let string, let args):
            
        case .array(let array):
            
        case .arraySelector(let index, let at):
            
        case .prefix(let `operator`, let right):
            
        case .postfix(let `operator`, let left):
            
        case .infix(let `operator`, let left, let right):
            
        }
        
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
