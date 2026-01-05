import ErrorHandle
import Foundation

extension Censor {
    struct AnyType: TypeDeclare {
        typealias RealType = Sendable
        static let name = "Any"
        let nullable: Bool
        
        let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: true)),
            "asCharacter": .init(returns: CharacterType(nullable: true)),
            "asInteger": .init(returns: IntegerType(nullable: true)),
            "asDecimal": .init(returns: DecimalType(nullable: true)),
            "asDate": .init(returns: DateType(nullable: true)),
            "asUUID": .init(returns: UUIDType(nullable: true)),
            "asBool": .init(returns: BoolType(nullable: true))
        ]
        
        static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ($0[0].cast(as: Any.self) as? String) },
            "asCharacter": .init { .succ($0[0].cast(as: Any.self) as? Character) },
            "asInteger": .init { .succ($0[0].cast(as: Any.self) as? Int64) },
            "asDecimal": .init { .succ($0[0].cast(as: Any.self) as? Decimal) },
            "asDate": .init { .succ($0[0].cast(as: Any.self) as? Date) },
            "asUUID": .init { .succ($0[0].cast(as: Any.self) as? UUID) },
            "asBool": .init { .succ($0[0].cast(as: Any.self) as? Bool) }
        ]
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
