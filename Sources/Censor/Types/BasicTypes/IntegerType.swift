import ErrorHandle
import Foundation

public extension Censor {
    struct IntegerType: TypeDeclare {
        public typealias RealType = Int64
        public static let name = "Int"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: false) }
                Action { .succ($0.cast(as: Int64.self).description) }
            },
            "asDate": .init {
                Return { DateType(nullable: false) }
                Action { .succ(Date(timeIntervalSince1970: Double($0.cast(as: Int64.self)) / 1000)) }
            },
            "asDecimal": .init {
                Return { DecimalType(nullable: false) }
                Action { .succ(Decimal($0.cast(as: Int64.self))) }
            }
        ]
        
        public static let infixOperations: [Operator : [Operation.Infix]] = [
            .plus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) + $1.cast(as: Int64.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ(Decimal($0.cast(as: Int64.self)) + $1.cast(as: Decimal.self)) }
                }
            ],
            .minus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) - $1.cast(as: Int64.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ(Decimal($0.cast(as: Int64.self)) - $1.cast(as: Decimal.self)) }
                }
            ],
            .multi: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) * $1.cast(as: Int64.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ(Decimal($0.cast(as: Int64.self)) * $1.cast(as: Decimal.self)) }
                }
            ],
            .divide: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) / $1.cast(as: Int64.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ(Decimal($0.cast(as: Int64.self)) / $1.cast(as: Decimal.self)) }
                }
            ],
            .mode: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) % $1.cast(as: Int64.self)) }
                }
            ],
            .exp: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ(pow(Decimal($0.cast(as: Int64.self)), Int($1.cast(as: Int64.self)))) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ(Decimal(powl(Double($0.cast(as: Int64.self)), ($1.cast(as: Decimal.self) as NSDecimalNumber).doubleValue))) }
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    IntegerType(nullable: true)
                    InfixAction { .succ($0.cast(as: Int64?.self) == $1.cast(as: Int64?.self)) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    DecimalType(nullable: true)
                    InfixAction { .succ($0.cast(as: Int64?.self) == ($1.cast(as: Decimal?.self) as? NSDecimalNumber)?.int64Value) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) < $1.cast()) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Int64.self) < ($1.cast(as: Decimal.self) as NSDecimalNumber).int64Value) }
                }
            ]
        ]
        
        public static let prefixOperations: [Operator : [Operation.Prefix]] = [
            .plus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Action { .succ($0.cast(as: Int64.self)) }
                }
            ],
            .minus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Action { .succ(-$0.cast(as: Int64.self)) }
                }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
