import ErrorHandle
import Foundation

extension Censor {
    struct DecimalType: TypeDeclare {
        typealias RealType = Decimal
        static let name = "Decimal"
        let nullable: Bool
        
        static let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false)),
            "asDate": .init(returns: DateType(nullable: true)),
            "asInteger": .init(returns: IntegerType(nullable: false))
        ]
        
        let infixOperations: [Symbol.InfixOperator : [OperationDeclare.Infix]] = [
            .plus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
            ],
            .minus: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
            ],
            .multi: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
            ],
            .divide: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
            ],
            .exp: [
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { DecimalType(nullable: true) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { IntegerType(nullable: true) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                }
            ]
        ]
        
        let prefixOperations: [Symbol.PrefixOperator : OperationDeclare.Prefix] = [
            .positive: .init {
                Return { DecimalType(nullable: false) }
                false
            },
            .negetive: .init {
                Return { DecimalType(nullable: false) }
                false
            }
        ]
        
        static let propertyActions: [String : Censor.ExecutableAction] = [
            "asString": .init { .succ($0.first!.cast(as: Decimal.self).description) },
            "asDate": .init { .succ(Date(timeIntervalSince1970: ($0.first!.cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) },
            "asInteger": .init { .succ(($0.first!.cast(as: Decimal.self) as NSDecimalNumber).int64Value) }
        ]
        
        static let infixOpActions: [Censor.Symbol.InfixOperator : [String : ExecutableAction]] = [
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
        
        static let prefixOpActions: [Censor.Symbol.PrefixOperator : ExecutableAction] = [
            .positive: .init { .succ($0.first!.cast(as: Decimal.self)) },
            .negetive: .init { .succ(-$0.first!.cast(as: Decimal.self)) }
        ]
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
