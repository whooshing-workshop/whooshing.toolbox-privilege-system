import ErrorHandle
import Foundation

extension Censor {
    struct TrueType: TypeDeclare {
        typealias RealType = String
        static let name = "TrueType"
        let nullable: Bool
        let type: any TypeDeclare.Type
        
        var properties: [String : PropertyDeclare] {
            type.staticProperties
        }
        
        var functions: [String: FunctionDeclare] {
            type.staticFunctions
        }
        
        init(nullable: Bool) {
            self = Self.init(nullable: nullable, type: AnyType.self)
        }
        
        init(nullable: Bool, type: any TypeDeclare.Type) {
            self.nullable = nullable
            self.type = type
        }
    }
}
