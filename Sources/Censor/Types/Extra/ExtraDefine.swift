extension Censor {
    enum Extra: TokenUnit {
        case eof
        case invalid
        
        var description: String {
            switch self {
            case .eof: "EOF"
            case .invalid: "INVALID"
            }
        }
    }
}
