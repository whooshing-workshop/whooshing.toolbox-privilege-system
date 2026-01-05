extension Censor.Symbol {
    struct AnyPrecedence: Precedence.Declare {
        let power: Int
        let associative: Precedence.Associative
        var any: Censor.Symbol.AnyPrecedence { fatalError() }
        
        init<T: Precedence.Declare>(_ pre: T) {
            self.power = pre.power
            self.associative = pre.associative
        }
    }
    
    enum Precedence {
        enum Associative: Sendable, Hashable {
            case left
            case right
            case none
        }

        protocol Declare: Sendable, Hashable {
            var power: Int { get }
            var associative: Associative { get }
            var any: AnyPrecedence { get }
        }

        struct Ternary: Declare {
            let power = 100
            let associative: Associative = .right
        }

        struct LogicOr: Declare {
            let power = 200
            let associative: Associative = .left
        }

        struct LogicAnd: Declare {
            let power = 300
            let associative: Associative = .left
        }

        struct Comparison: Declare {
            let power = 400
            let associative: Associative = .none
        }

        struct NilCoalescing: Declare {
            let power = 500
            let associative: Associative = .right
        }

        struct Addition: Declare {
            let power = 600
            let associative: Associative = .left
        }

        struct Multiplication: Declare {
            let power = 700
            let associative: Associative = .left
        }

        struct Exponentiation: Declare {
            let power = 800
            let associative: Associative = .left
        }

        struct Prefix: Declare {
            let power = 900
            let associative: Associative = .none
        }

        struct Postfix: Declare {
            let power = 1000
            let associative: Associative = .none
        }
    }
}

extension Censor.Symbol.Precedence.Declare {
    var any: Censor.Symbol.AnyPrecedence { .init(self) }
}
