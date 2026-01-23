extension Censor.Symbol {
    protocol Delimiter: Define, Infix {
        var name: String { get }
    }
    
    static let delimiters: [any Define] = [
        Comma()
    ]
}

extension Censor.Symbol.Delimiter {
    var description: String { "Delimiter.\(name)" }
}

// MARK: - Delimiter

extension Censor.Symbol {
    struct Comma: Delimiter {
        let lexeme = ","
        let name = "COMMA"
        let spacing: Spacing = .any
    }
}
