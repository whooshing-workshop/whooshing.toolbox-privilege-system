import ErrorHandle
import Foundation

public extension Censor {
    struct AnyType: TypeDeclare {
        public typealias RealType = Any
        public static let name = "Any"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? String) }
            },
            "asCharacter": .init {
                Return { CharacterType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? Character) }
            },
            "asInteger": .init {
                Return { IntegerType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? Int64) }
            },
            "asDecimal": .init {
                Return { DecimalType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? Decimal) }
            },
            "asDate": .init {
                Return { DateType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? Date) }
            },
            "asUUID": .init {
                Return { UUIDType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? UUID) }
            },
            "asBool": .init {
                Return { BoolType(nullable: true) }
                Action { .succ($0.cast(as: Any.self) as? Bool) }
            }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
