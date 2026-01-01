import ErrorHandle
import Foundation

public extension Censor {
    struct BoolType: TypeDeclare {
        public typealias RealType = Bool
        public static let name = "Bool"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false)),
            "asInteger": .init(returns: IntegerType(nullable: false)),
            "asDecimal": .init(returns: DecimalType(nullable: false))
        ]
        
        public let infixOperations: [Operator.Infix : [OperationDeclare.Infix]] = [
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { BoolType(nullable: true) }
                }
            ],
            .and: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { BoolType(nullable: false) }
                }
            ],
            .or: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    Right { BoolType(nullable: false) }
                }
            ]
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ(String($0.first!.cast(as: Bool.self))) },
            "asInteger": .init { .succ(Int64($0.first!.cast() ? 1 : 0)) },
            "asDecimal": .init { .succ(Decimal($0.first!.cast() ? 1 : 0)) },
        ]
        
        public static let infixOpActions: [Censor.Operator.Infix : [String : ExecutableAction]] = [
            .equal: [
                BoolType.name: .init { .succ($0[0].cast(as: Bool?.self) == $0[1].cast(as: Bool?.self)) }
            ],
            .and: [
                BoolType.name: .init { .succ($0[0].cast(as: Bool.self) && $0[1].cast(as: Bool.self)) }
            ],
            .or: [
                BoolType.name: .init { .succ($0[0].cast(as: Bool.self) || $0[1].cast(as: Bool.self)) }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
