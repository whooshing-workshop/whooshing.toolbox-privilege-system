import ErrorHandle
import Foundation

public extension Censor {
    struct CharacterType: TypeDeclare {
        public typealias RealType = Character
        public static let name = "Character"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asString": .init {
                Return { StringType(nullable: false) }
                Action { .succ(String($0.cast(as: Character.self))) }
            }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
