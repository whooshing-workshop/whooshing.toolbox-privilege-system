import ErrorHandle
import Foundation

public extension Censor {
    struct DecimalType: TypeDeclare {
        public typealias RealType = Decimal
        public static let name = "Decimal"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: false) }
                Action { .succ($0.cast(as: Decimal.self).description) }
            },
            "asDate": .init {
                Return { DateType(nullable: true) }
                Action { .succ(Date(timeIntervalSince1970: ($0.cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) }
            },
            "asInteger": .init {
                Return { IntegerType(nullable: false) }
                Action { .succ(($0.cast(as: Decimal.self) as NSDecimalNumber).int64Value) }
            }
        ]
        
        public static let infixOperations: [Operator : [Operation.Infix]] = [
            .plus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) + $1.cast(as: Decimal.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) + Decimal($1.cast(as: Int64.self))) }
                },
            ],
            .minus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) - $1.cast(as: Decimal.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) - Decimal($1.cast(as: Int64.self))) }
                },
            ],
            .multi: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) * $1.cast(as: Decimal.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) * Decimal($1.cast(as: Int64.self))) }
                },
            ],
            .divide: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) / $1.cast(as: Decimal.self)) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) / Decimal($1.cast(as: Int64.self))) }
                },
            ],
            .exp: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ(pow($0.cast(as: Decimal.self), Int($1.cast(as: Int64.self)))) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ(Decimal(powl(($0.cast(as: Decimal.self) as NSDecimalNumber).doubleValue, ($1.cast(as: Decimal.self) as NSDecimalNumber).doubleValue))) }
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    DecimalType(nullable: true)
                    InfixAction { .succ($0.cast(as: Decimal?.self) == $1.cast(as: Decimal?.self)) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    IntegerType(nullable: true)
                    InfixAction { .succ(($0.cast(as: Decimal?.self) as? NSDecimalNumber)?.int64Value == $1.cast(as: Int64?.self)) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Decimal.self) < $1.cast()) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ(($0.cast(as: Decimal.self) as NSDecimalNumber).int64Value < $1.cast(as: Int64.self)) }
                }
            ]
        ]
        
        public static let prefixOperations: [Operator : [Operation.Prefix]] = [
            .plus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Action { .succ($0.cast(as: Decimal.self)) }
                }
            ],
            .minus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Action { .succ(-$0.cast(as: Decimal.self)) }
                }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
