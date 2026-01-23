public extension Censor {
    enum Keyword {
        public protocol Define: TokenUnit, Sendable {
            var lexeme: String { get }
            var name: String { get }
        }
    }
    
    static let keywords: [Keyword.Define] = [
        Keyword.IN()
    ]
}

extension Censor.Keyword.Define {
    public var description: String {
        "Keyword.\(name)"
    }
}
