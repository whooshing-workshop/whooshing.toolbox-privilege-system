import ErrorHandle
import Foundation

extension Censor {
    struct CharacterType: TypeDeclare {
        typealias RealType = Character
        static let name = "Character"
        let nullable: Bool
        
        let properties: [String : PropertyDeclare] = [
            "asString": .init(returns: StringType(nullable: false))
        ]
        
        static let propertyActions: [String : ExecutableAction] = [
            "asString": .init { .succ(String($0.first!.cast(as: Character.self))) }
        ]
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
