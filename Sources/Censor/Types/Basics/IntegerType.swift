import ErrorHandle
import Foundation

extension Censor {
    struct IntegerType: TypeDeclare {
        typealias RealType = Int64
        static let name = BasicType.integer.rawValue
        let nullable: Bool
        
        let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false)),
            "asDate": .init(returns: DateType(nullable: false)),
            "asDecimal": .init(returns: DecimalType(nullable: false))
        ]
        
        let infixOperations: [Symbol.InfixOperator : [OperationDeclare.Infix]] = [
            .plus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .minus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .multi: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .divide: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .mode: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                }
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
                    Right { IntegerType(nullable: true) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { DecimalType(nullable: true) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ]
        ]
        
        let prefixOperations: [Symbol.PrefixOperator : OperationDeclare.Prefix] = [
            .positive: .init {
                Return { IntegerType(nullable: false) }
                false
            },
            .negative: .init {
                Return { IntegerType(nullable: false) }
                false
            }
        ]
        
        static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ($0[0].cast(as: Int64.self).description) },
            "asDate": .init { .succ(Date(timeIntervalSince1970: Double($0[0].cast(as: Int64.self)) / 1000)) },
            "asDecimal": .init { .succ(Decimal($0[0].cast(as: Int64.self))) }
        ]
        
        static let infixOpActions: [Symbol.InfixOperator : [String : ExecutableAction]] = [
            .plus: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64.self) + $0[1].cast(as: Int64.self)) },
                DecimalType.name: .init { .succ(Decimal($0[0].cast(as: Int64.self)) + $0[1].cast(as: Decimal.self)) }
            ],
            .minus: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64.self) - $0[1].cast(as: Int64.self)) },
                DecimalType.name: .init { .succ(Decimal($0[0].cast(as: Int64.self)) - $0[1].cast(as: Decimal.self)) }
            ],
            .multi: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64.self) * $0[1].cast(as: Int64.self)) },
                DecimalType.name: .init { .succ(Decimal($0[0].cast(as: Int64.self)) * $0[1].cast(as: Decimal.self)) }
            ],
            .divide: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64.self) / $0[1].cast(as: Int64.self)) },
                DecimalType.name: .init { .succ(Decimal($0[0].cast(as: Int64.self)) / $0[1].cast(as: Decimal.self)) }
            ],
            .mode: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64.self) % $0[1].cast(as: Int64.self)) }
            ],
            .exp: [
                IntegerType.name: .init { .succ(pow(Decimal($0[0].cast(as: Int64.self)), Int($0[1].cast(as: Int64.self)))) },
                DecimalType.name: .init { .succ(Decimal(powl(Double($0[0].cast(as: Int64.self)), ($0[1].cast(as: Decimal.self) as NSDecimalNumber).doubleValue))) }
            ],
            .equal: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64?.self) == $0[1].cast(as: Int64?.self)) },
                DecimalType.name: .init { .succ($0[0].cast(as: Int64?.self) == ($0[1].cast(as: Decimal?.self) as? NSDecimalNumber)?.int64Value) }
            ],
            .less: [
                IntegerType.name: .init { .succ($0[0].cast(as: Int64.self) < $0[1].cast()) },
                DecimalType.name: .init { .succ($0[0].cast(as: Int64.self) < ($0[1].cast(as: Decimal.self) as NSDecimalNumber).int64Value) }
            ]
        ]
        
        static let prefixOpActions: [Censor.Symbol.PrefixOperator : ExecutableAction] = [
            .positive: .init { .succ($0[0].cast(as: Int64.self)) },
            .negative: .init { .succ(-$0[0].cast(as: Int64.self)) }
        ]
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
