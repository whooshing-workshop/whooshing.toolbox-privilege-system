import ErrorHandle
import Foundation

public extension Censor {
    struct DateType: TypeDeclare {
        public typealias RealType = Date
        public static let name = "Date"
        public static let dateFormatter = ISO8601DateFormatter()
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: false) }
                Action { .succ(Self.dateFormatter.string(from: $0.cast())) }
            },
            "timeIntervalSince1970": .init {
                Return { IntegerType(nullable: false) }
                Action { .succ(Int64($0.cast(as: Date.self).timeIntervalSince1970 * 1000)) }
            }
        ]
        
        public static let staticProperties: [String : Property] = [
            "now": .init {
                Return { DateType(nullable: false) }
                Action { _ in .succ(Date()) }
            }
        ]
        
        public static let functions: [String : Function] = [
            "timeInterval": .init {
                Return { IntegerType(nullable: false) }
                ArgumentDeclare {
                    ("since", DateType(nullable: false)) >- nil
                }
                FunctionAction {
                    .succ(Int64($0.cast(as: Date.self).timeIntervalSince($1[0].cast()) * 1000))
                }
            }
        ]
        
        public static let infixOperations: [Operator : [Operation.Infix]] = [
            .plus: [
                .init {
                    Return { DateType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Date.self) + (Double($1.cast(as: Int64.self)) / 1000)) }
                },
                .init {
                    Return { DateType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Date.self) + (($1.cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) }
                }
            ],
            .minus: [
                .init {
                    Return { DateType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: Date.self) - (Double($1.cast(as: Int64.self)) / 1000)) }
                },
                .init {
                    Return { DateType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: Date.self) - (($1.cast(as: Decimal.self) / 1000 as NSDecimalNumber).doubleValue)) }
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    DateType(nullable: true)
                    InfixAction { .succ($0.cast(as: Date?.self) == $1.cast(as: Date?.self)) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    DateType(nullable: false)
                    InfixAction { .succ($0.cast(as: Date.self) < $1.cast(as: Date.self)) }
                }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
