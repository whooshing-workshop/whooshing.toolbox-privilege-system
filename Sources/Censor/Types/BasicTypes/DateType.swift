import ErrorHandle
import Foundation

public extension Censor {
    struct DateType: TypeDeclare {
        public typealias RealType = Date
        public static let name = "Date"
        public static let dateFormatter = ISO8601DateFormatter()
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false)),
            "timeIntervalSince1970": .init(returns: IntegerType(nullable: false))
        ]
        
        public static let staticProperties: [String : PropertyDeclare] = [
            "now": .init(returns: DateType(nullable: false))
        ]
        
        public let functions: [String : FunctionDeclare] = [
            "timeInterval": .init {
                Return { IntegerType(nullable: false) }
                ArgumentDeclare {
                    ("since", { DateType(nullable: false) }) >- nil
                }
            }
        ]
        
        public let infixOperations: [Operator.Infix : [OperationDeclare.Infix]] = [
            .plus: [
                .init {
                    Return { DateType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DateType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .minus: [
                .init {
                    Return { DateType(nullable: false) }
                    false
                    Right { IntegerType(nullable: false) }
                },
                .init {
                    Return { DateType(nullable: false) }
                    false
                    Right { DecimalType(nullable: false) }
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { DateType(nullable: true) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { DateType(nullable: false) }
                }
            ]
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ(Self.dateFormatter.string(from: $0.first!.cast())) },
            "timeIntervalSince1970": .init { .succ(Int64($0.first!.cast(as: Date.self).timeIntervalSince1970 * 1000)) }
        ]
        
        public static let functionActions: [String : ExecutableAction] = [
            "timeInterval": .init { .succ(Int64($0[0].cast(as: Date.self).timeIntervalSince($0[1].cast()) * 1000)) }
        ]
        
        public static let infixOpActions: [Censor.Operator.Infix : [String : ExecutableAction]] = [
            .plus: [
                IntegerType.name: .init { .succ($0[0].cast(as: Date.self) + (Double($0[1].cast(as: Int64.self)) / 1000)) },
                DecimalType.name: .init { .succ($0[0].cast(as: Date.self) + (($0[1].cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) }
            ],
            .minus: [
                IntegerType.name: .init { .succ($0[0].cast(as: Date.self) - (Double($0[1].cast(as: Int64.self)) / 1000)) },
                DecimalType.name: .init { .succ($0[0].cast(as: Date.self) - (($0[1].cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) }
            ],
            .equal: [
                DateType.name: .init { .succ($0[0].cast(as: Date?.self) == $0[1].cast(as: Date?.self)) }
            ],
            .less: [
                DateType.name: .init { .succ($0[0].cast(as: Date.self) < $0[1].cast(as: Date.self)) }
            ]
        ]
        
        public static let staticPropertieActions: [String : ExecutableAction] = [
            "now": .init { _ in .succ(Date()) }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}

extension ISO8601DateFormatter: @unchecked @retroactive Sendable {}
