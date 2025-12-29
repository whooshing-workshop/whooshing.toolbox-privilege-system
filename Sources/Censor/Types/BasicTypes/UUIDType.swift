import ErrorHandle
import Foundation

public extension Censor {
    struct UUIDType: TypeDeclare {
        public typealias RealType = UUID
        public static let name = "UUID"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: false) }
                Action { .succ($0.cast(as: UUID.self).uuidString) }
            }
        ]
        
        public static let staticProperties: [String : Property] = [
            "new": .init {
                Return { UUIDType(nullable: false) }
                Action { _ in .succ(UUID()) }
            }
        ]
        
        public static let infixOperations: [Operator : [Operation.Infix]] = [
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    UUIDType(nullable: true)
                    InfixAction { .succ($0.cast(as: UUID?.self) == $1.cast(as: UUID?.self)) }
                }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
