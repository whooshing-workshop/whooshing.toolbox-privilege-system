import ErrorHandle
import Foundation

public extension Censor {
    struct UUIDType: TypeDeclare {
        public typealias RealType = UUID
        public static let name = "UUID"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false))
        ]
        
        public let staticProperties: [String : PropertyDeclare] = [
            "new": .init(returns: UUIDType(nullable: false))
        ]
        
        public let infixOperations: [Operator.Infix : [OperationDeclare.Infix]] = [
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    Right { UUIDType(nullable: true) }
                }
            ]
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ($0.first!.cast(as: UUID.self).uuidString) }
        ]
        
        public static let staticPropertieActions: [String : ExecutableAction] = [
            "new": .init { _ in .succ(UUID()) }
        ]
        
        public static let infixOpActions: [Operator.Infix : [String : ExecutableAction]] = [
            .equal: [
                UUIDType.name: .init { .succ($0[0].cast(as: UUID?.self) == $0[1].cast(as: UUID?.self)) }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
