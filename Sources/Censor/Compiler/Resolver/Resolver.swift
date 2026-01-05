extension Censor {
    class Resolver {
        let ast: AST
        let source: String
        let globals: [any TypeDeclare] = []
        
        var current = 0
        var diagnostics: [Censor.Error] = []
        
        init(ast: AST, source: String) {
            self.ast = ast
            self.source = source
        }
        
        func resolve() -> Result {
            
        }
    }
}

extension Censor.Resolver {
    public struct Result {
        public let content: (Censor.AST, Censor.Map)?
        public let diagnostics: [any Swift.Error]
        public let source: String
        
        public var hasErrors: Bool {
            !diagnostics.isEmpty
        }
    }
}
