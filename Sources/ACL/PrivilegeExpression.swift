public struct PrivilegeExpression: Sendable, Codable {
    public let ast: AST
    public let expression: String
    
    public init(ast: AST, expression: String) {
        self.ast = ast
        self.expression = expression
    }
}

extension PrivilegeExpression: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.expression = value
        fatalError()
    }
}
