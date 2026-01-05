extension Censor.Symbol {
    public enum Precedence {
        public enum Associative: Sendable, Hashable {
            case left
            case right
            case none
        }

        public protocol Declare: Sendable, Hashable, Comparable {
            var power: Int { get }
            var associative: Associative { get }
            var any: AnyPrecedence { get }
        }
    }

    public struct AnyPrecedence: Precedence.Declare {
        public let power: Int
        public let associative: Precedence.Associative
        public var any: Censor.Symbol.AnyPrecedence { self }
        
        public init<T: Precedence.Declare>(_ pre: T) {
            self.power = pre.power
            self.associative = pre.associative
        }
        
        public init(power: Int, associative: Precedence.Associative) {
            self.power = power
            self.associative = associative
        }

        /// 判断当前运算符在此上下文（context）中是否具有更强的绑定力
        public func bindsTighter(than context: Censor.Symbol.AnyPrecedence) -> Bool {
            if self.power > context.power { return true }
            
            // 右结合逻辑：如果优先级相等，新来的运算符（self）会赢过之前的上下文
            if self.power == context.power && self.associative == .right {
                return true
            }
            
            return false
        }
    }
}

extension Censor.Symbol.Precedence.Declare {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.power < rhs.power
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.power == rhs.power && lhs.associative == rhs.associative
    }
    
    public var any: Censor.Symbol.AnyPrecedence { .init(self) }
}

extension Censor.Symbol.Precedence {
    public struct Lowest: Declare {
        public let power = 0
        public let associative: Associative = .none
        public init() {}
    }

    public struct Ternary: Declare {
        public let power = 100
        public let associative: Associative = .right
        public init() {}
    }

    public struct LogicOr: Declare {
        public let power = 200
        public let associative: Associative = .left
        public init() {}
    }

    public struct LogicAnd: Declare {
        public let power = 300
        public let associative: Associative = .left
        public init() {}
    }

    public struct Comparison: Declare {
        public let power = 400
        public let associative: Associative = .none
        public init() {}
    }

    public struct NilCoalescing: Declare {
        public let power = 500
        public let associative: Associative = .right
        public init() {}
    }

    public struct Addition: Declare {
        public let power = 600
        public let associative: Associative = .left
        public init() {}
    }

    public struct Multiplication: Declare {
        public let power = 700
        public let associative: Associative = .left
        public init() {}
    }

    public struct Exponentiation: Declare {
        public let power = 800
        public let associative: Associative = .left
        public init() {}
    }

    public struct Prefix: Declare {
        public let power = 900
        public let associative: Associative = .none
        public init() {}
    }

    public struct Postfix: Declare {
        public let power = 1000
        public let associative: Associative = .none
        public init() {}
    }
}
