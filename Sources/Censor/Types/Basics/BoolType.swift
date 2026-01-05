import ErrorHandle
import Foundation

extension Censor {
    struct BoolType: TypeDeclare {
        typealias RealType = Bool
        static let name = "Bool"
        let nullable: Bool
        
        let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false)),
            "asInteger": .init(returns: IntegerType(nullable: false)),
            "asDecimal": .init(returns: DecimalType(nullable: false))
        ]
        
        let infixOperations: [Symbol.InfixOperator : [OperationDeclare.Infix]] = [
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
        
        static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ(String($0.first!.cast(as: Bool.self))) },
            "asInteger": .init { .succ(Int64($0.first!.cast() ? 1 : 0)) },
            "asDecimal": .init { .succ(Decimal($0.first!.cast() ? 1 : 0)) },
        ]
        
        static let infixOpActions: [Censor.Symbol.InfixOperator : [String : ExecutableAction]] = [
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
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
