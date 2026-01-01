import ErrorHandle
import Foundation

public extension Censor {
    struct AnyType: TypeDeclare {
        public typealias RealType = Sendable
        public static let name = "Any"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: true)),
            "asCharacter": .init(returns: CharacterType(nullable: true)),
            "asInteger": .init(returns: IntegerType(nullable: true)),
            "asDecimal": .init(returns: DecimalType(nullable: true)),
            "asDate": .init(returns: DateType(nullable: true)),
            "asUUID": .init(returns: UUIDType(nullable: true)),
            "asBool": .init(returns: BoolType(nullable: true))
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ($0.first!.cast(as: Any.self) as? String) },
            "asCharacter": .init { .succ($0.first!.cast(as: Any.self) as? Character) },
            "asInteger": .init { .succ($0.first!.cast(as: Any.self) as? Int64) },
            "asDecimal": .init { .succ($0.first!.cast(as: Any.self) as? Decimal) },
            "asDate": .init { .succ($0.first!.cast(as: Any.self) as? Date) },
            "asUUID": .init { .succ($0.first!.cast(as: Any.self) as? UUID) },
            "asBool": .init { .succ($0.first!.cast(as: Any.self) as? Bool) }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
