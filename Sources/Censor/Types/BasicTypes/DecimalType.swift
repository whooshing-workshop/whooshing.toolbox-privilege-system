import ErrorHandle
import Foundation

public extension Censor {
    struct DecimalType: TypeDeclare {
        public typealias RealType = Decimal
        public static let name = "Decimal"
        public let nullable: Bool
        
        public static let properties: [String : PropertyDeclare] = [
            "asString": .init { StringType(nullable: false) },
            "asDate": .init { DateType(nullable: true) },
            "asInteger": .init { IntegerType(nullable: false) }
        ]
        
        public let infixOperations: [Operator.Infix : [OperationDeclare.Infix]] = [
            .plus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
            ],
            .minus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
            ],
            .multi: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
            ],
            .divide: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
            ],
            .exp: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    DecimalType(nullable: true)
                },
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    IntegerType(nullable: true)
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                },
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                }
            ]
        ]
        
        public let prefixOperations: [Operator.Prefix : OperationDeclare.Prefix] = [
            .positive: .init {
                Return { DecimalType(nullable: false) }
                false
            },
            .negetive: .init {
                Return { DecimalType(nullable: false) }
                false
            }
        ]
        
        public static let propertyActions: [String : Censor.ExecutableAction] = [
            "asString": .init { .succ($0.first!.cast(as: Decimal.self).description) },
            "asDate": .init { .succ(Date(timeIntervalSince1970: ($0.first!.cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) },
            "asInteger": .init { .succ(($0.first!.cast(as: Decimal.self) as NSDecimalNumber).int64Value) }
        ]
        
        public static let infixOpActions: [Censor.Operator.Infix : [String : ExecutableAction]] = [
            .plus: [
                DecimalType.name: .init { .succ($0[0].cast(as: Decimal.self) + $0[1].cast(as: Decimal.self)) },
                IntegerType.name: .init { .succ($0[0].cast(as: Decimal.self) + Decimal($0[1].cast(as: Int64.self))) }
            ],
            .minus: [
                DecimalType.name: .init { .succ($0[0].cast(as: Decimal.self) - $0[1].cast(as: Decimal.self)) },
                IntegerType.name: .init { .succ($0[0].cast(as: Decimal.self) - Decimal($0[1].cast(as: Int64.self))) }
            ],
            .multi: [
                DecimalType.name: .init { .succ($0[0].cast(as: Decimal.self) * $0[1].cast(as: Decimal.self)) },
                IntegerType.name: .init { .succ($0[0].cast(as: Decimal.self) * Decimal($0[1].cast(as: Int64.self))) }
            ],
            .divide: [
                DecimalType.name: .init { .succ($0[0].cast(as: Decimal.self) / $0[1].cast(as: Decimal.self)) },
                IntegerType.name: .init { .succ($0[0].cast(as: Decimal.self) / Decimal($0[1].cast(as: Int64.self))) }
            ],
            .exp: [
                DecimalType.name: .init { .succ(pow($0[0].cast(as: Decimal.self), Int($0[1].cast(as: Int64.self)))) },
                IntegerType.name: .init { .succ(Decimal(powl(($0[0].cast(as: Decimal.self) as NSDecimalNumber).doubleValue, ($0[1].cast(as: Decimal.self) as NSDecimalNumber).doubleValue))) }
            ],
            .equal: [
                DecimalType.name: .init { .succ($0[0].cast(as: Decimal?.self) == $0[1].cast(as: Decimal?.self)) },
                IntegerType.name: .init { .succ(($0[0].cast(as: Decimal?.self) as? NSDecimalNumber)?.int64Value == $0[1].cast(as: Int64?.self)) }
            ],
            .less: [
                DecimalType.name: .init { .succ($0[0].cast(as: Decimal.self) < $0[1].cast()) },
                IntegerType.name: .init { .succ(($0[0].cast(as: Decimal.self) as NSDecimalNumber).int64Value < $0[1].cast(as: Int64.self)) }
            ]
        ]
        
        public static let prefixOpActions: [Censor.Operator.Prefix : ExecutableAction] = [
            .positive: .init { .succ($0.first!.cast(as: Decimal.self)) },
            .negetive: .init { .succ(-$0.first!.cast(as: Decimal.self)) }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
