import ErrorHandle
import Foundation

public extension Censor {
    struct AnyType: TypeDeclare {
        public typealias RealType = Any
        public static let name = "Any"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init { StringType(nullable: true) },
            "asCharacter": .init { CharacterType(nullable: true) },
            "asInteger": .init { IntegerType(nullable: true) },
            "asDecimal": .init { DecimalType(nullable: true) },
            "asDate": .init { DateType(nullable: true) },
            "asUUID": .init { UUIDType(nullable: true) },
            "asBool": .init { BoolType(nullable: true) }
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
