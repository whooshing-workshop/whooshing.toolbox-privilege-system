import ErrorHandle
import Foundation

public extension Censor {
    struct CharacterType: TypeDeclare {
        public typealias RealType = Character
        public static let name = "Character"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false))
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ(String($0.first!.cast(as: Character.self))) }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
