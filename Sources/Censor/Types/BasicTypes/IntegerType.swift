import ErrorHandle
import Foundation

public extension Censor {
    struct IntegerType: TypeDeclare {
        public typealias RealType = Int64
        public static let name = "Int"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init { StringType(nullable: false) },
            "asDate": .init { DateType(nullable: false) },
            "asDecimal": .init { DecimalType(nullable: false) }
        ]
        
        public let infixOperations: [Operator.Infix : [OperationDeclare.Infix]] = [
            .plus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                }
            ],
            .minus: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                }
            ],
            .multi: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                }
            ],
            .divide: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { DecimalType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                }
            ],
            .mode: [
                .init {
                    Return { IntegerType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                }
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
                    IntegerType(nullable: true)
                },
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    DecimalType(nullable: true)
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                }
            ]
        ]
        
        public let prefixOperations: [Operator.Prefix : OperationDeclare.Prefix] = [
            .positive: .init {
                Return { IntegerType(nullable: false) }
                false
            },
            .negetive: .init {
                Return { IntegerType(nullable: false) }
                false
            }
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ($0.first!.cast(as: Int64.self).description) },
            "asDate": .init { .succ(Date(timeIntervalSince1970: Double($0.first!.cast(as: Int64.self)) / 1000)) },
            "asDecimal": .init { .succ(Decimal($0.first!.cast(as: Int64.self))) }
        ]
        
        public static let infixOpActions: [Operator.Infix : [String : ExecutableAction]] = [
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
        
        public static let prefixOpActions: [Censor.Operator.Prefix : ExecutableAction] = [
            .positive: .init { .succ($0.first!.cast(as: Int64.self)) },
            .negetive: .init { .succ(-$0.first!.cast(as: Int64.self)) }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
