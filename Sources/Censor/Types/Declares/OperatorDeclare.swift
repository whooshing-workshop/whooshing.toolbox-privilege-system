public extension Censor {
    enum Operator {
        public protocol Base: Sendable {
            var precedence: Precedence.Declare.Type { get }
        }
        
        public enum Infix: String, Sendable, Codable, CaseIterable, Base {
            case plus           = "+"
            case minus          = "-"
            case multi          = "*"
            case divide         = "/"
            case mode           = "%"
            case exp            = "^"

            case equal          = "=="
            case less           = "<"
            
            case and            = "&"
            case or             = "|"
            
            case notEqual       = "!="
            case greater        = ">"
            case lessEqual      = "<="
            case greaterEqual   = ">="
            
            public var precedence: Precedence.Declare.Type {
                switch self {
                case .exp: Precedence.Exponentiation.self
                case .multi, .divide, .mode: Precedence.Multiplication.self
                case .plus, .minus: Precedence.Addition.self
                case .equal, .less, .notEqual, .greater, .lessEqual, .greaterEqual: Precedence.Comparison.self
                case .and: Precedence.LogicAnd.self
                case .or: Precedence.LogicOr.self
                }
            }
        }
        
        public enum Prefix: String, Sendable, Codable, CaseIterable, Base {
            case positive       = "+"
            case negetive       = "-"
            
            public var precedence: Precedence.Declare.Type {
                switch self {
                case .positive, .negetive: Precedence.Prefix.self
                }
            }
        }
        
        public enum Postfix: String, Sendable, Codable, CaseIterable, Base {
            case placeholder     = "~"      // 无用，仅为了在此处占位防止 Swift 编译器报错
            
            public var precedence: Precedence.Declare.Type {
                switch self {
                case .placeholder: Precedence.Postfix.self
                }
            }
        }
    }
}

public extension Censor.Operator {
    enum Precedence {
        public enum Associative: Sendable {
            case left
            case right
            case none
        }
        
        public protocol Declare: Sendable {
            static var power: Int { get }
            static var associative: Associative { get }
        }
        
        public enum Ternary: Declare {
            public static let power = 100
            public static let associative: Associative = .right
        }

        public enum LogicOr: Declare {
            public static let power = 200
            public static let associative: Associative = .left
        }

        public enum LogicAnd: Declare {
            public static let power = 300
            public static let associative: Associative = .left
        }

        public enum Comparison: Declare {
            public static let power = 400
            public static let associative: Associative = .none
        }

        public enum NilCoalescing: Declare {
            public static let power = 500
            public static let associative: Associative = .right
        }

        public enum Addition: Declare {
            public static let power = 600
            public static let associative: Associative = .left
        }

        public enum Multiplication: Declare {
            public static let power = 700
            public static let associative: Associative = .left
        }

        public enum Exponentiation: Declare {
            public static let power = 800
            public static let associative: Associative = .left
        }

        public enum Prefix: Declare {
            public static let power = 900
            public static let associative: Associative = .none
        }

        public enum Postfix: Declare {
            public static let power = 1000
            public static let associative: Associative = .none
        }
    }
}

// MARK: - Log Descriptions
extension Censor.Operator.Infix: CustomStringConvertible {
    public var description: String {
        // 返回如: INFIX(+)
        return "Infix(\(self.rawValue))"
    }
}

extension Censor.Operator.Prefix: CustomStringConvertible {
    public var description: String {
        // 返回如: PREFIX(-)
        return "Prefix(\(self.rawValue))"
    }
}

extension Censor.Operator.Postfix: CustomStringConvertible {
    public var description: String {
        // 返回如: POSTFIX(~)
        return "Postfix(\(self.rawValue))"
    }
}
