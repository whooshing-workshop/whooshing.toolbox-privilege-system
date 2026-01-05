extension Censor.Keyword {
    static let null = NULL()
    struct NULL: Define {
        let lexeme = "nil"
        let name = "NULL"
    }
}
