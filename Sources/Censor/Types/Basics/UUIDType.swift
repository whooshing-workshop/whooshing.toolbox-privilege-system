import ErrorHandle
import Foundation

extension Censor {
    struct UUIDType: TypeDeclare {
        typealias RealType = UUID
        static let name = "UUID"
        let nullable: Bool
        
        let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false))
        ]
        
        let staticProperties: [String : PropertyDeclare] = [
            "new": .init(returns: UUIDType(nullable: false))
        ]
        
        let infixOperations: [Symbol.InfixOperator : [OperationDeclare.Infix]] = [
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { UUIDType(nullable: true) }
                }
            ]
        ]
        
        static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ($0.first!.cast(as: UUID.self).uuidString) }
        ]
        
        static let staticPropertieActions: [String : ExecutableAction] = [
            "new": .init { _ in .succ(UUID()) }
        ]
        
        static let infixOpActions: [Symbol.InfixOperator : [String : ExecutableAction]] = [
            .equal: [
                UUIDType.name: .init { .succ($0[0].cast(as: UUID?.self) == $0[1].cast(as: UUID?.self)) }
            ]
        ]
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
