extension Censor.Symbol {
    protocol Punctuator: Sendable {
        associatedtype Left: Define, CustomStringConvertible
        associatedtype Right: Define, CustomStringConvertible

        var left: Left { get }
        var right: Right { get }
    }
    
    static let punctuators: [any Punctuator] = [
        Paren(),
        Square(),
        Curly()
    ]
    
    static let leftPunctuators: [Define] = punctuators.map { $0.left }
    static let rightPunctuators: [Define] = punctuators.map { $0.right }
}

// MARK: - Punctuator Defines

extension Censor.Symbol {
    struct Paren: Punctuator {
        static let name = "PAREN"
        struct Left: Define, CustomStringConvertible {
            let lexeme = "("
            let spacing: Spacing = .any
            
            let description = "Punctuator.\(name)_L"
        }

        struct Right: Define, CustomStringConvertible {
            let lexeme = ")"
            let spacing: Spacing = .any
            
            let description = "Punctuator.\(name)_R"
        }
        
        let left = Left()
        let right = Right()
    }

    struct Square: Punctuator {
        static let name = "SQUARE"
        struct Left: Define, CustomStringConvertible {
            let lexeme = "["
            let spacing: Spacing = .any
            
            let description = "Punctuator.\(name)_L"
        }

        struct Right: Define, CustomStringConvertible {
            let lexeme = "]"
            let spacing: Spacing = .any
            
            let description = "Punctuator.\(name)_R"
        }
        
        let left = Left()
        let right = Right()
    }
    
    struct Curly: Punctuator {
        static let name = "CURLY"
        struct Left: Define, CustomStringConvertible {
            let lexeme = "{"
            let spacing: Spacing = .any
            
            let description = "Punctuator.\(name)_L"
        }

        struct Right: Define, CustomStringConvertible {
            let lexeme = "}"
            let spacing: Spacing = .any
            
            let description = "Punctuator.\(name)_R"
        }
        
        let left = Left()
        let right = Right()
    }
}
