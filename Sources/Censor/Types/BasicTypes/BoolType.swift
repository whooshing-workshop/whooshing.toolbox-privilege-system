import ErrorHandle
import Foundation

public extension Censor {
    struct BoolType: TypeDeclare {
        public typealias RealType = Bool
        public static let name = "Bool"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: false) }
                Action { .succ(String($0.cast(as: Bool.self))) }
            },
            "asInteger": .init {
                Return { IntegerType(nullable: false) }
                Action { .succ(Int64($0.cast() ? 1 : 0)) }
            },
            "asDecimal": .init {
                Return { DecimalType(nullable: false) }
                Action { .succ(Decimal($0.cast() ? 1 : 0)) }
            },
        ]
        
        public static let infixOperations: [Operator : [Operation.Infix]] = [
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    BoolType(nullable: true)
                    InfixAction { .succ($0.cast(as: Bool?.self) == $1.cast(as: Bool?.self)) }
                }
            ],
            .and: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    BoolType(nullable: false)
                    InfixAction { .succ($0.cast(as: Bool.self) && $1.cast(as: Bool.self)) }
                }
            ],
            .or: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    BoolType(nullable: false)
                    InfixAction { .succ($0.cast(as: Bool.self) || $1.cast(as: Bool.self)) }
                }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
