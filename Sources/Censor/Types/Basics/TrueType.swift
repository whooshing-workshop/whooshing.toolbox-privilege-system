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
            fatalError("不应直接创建 TrueType")
        }
        
        init(real: any TypeDeclare.Type) {
            self.nullable = false
            self.type = real
        }
        
        init<T: TypeDeclare>(type: T) {
            self.nullable = false
            self.type = T.self
        }
    }
}
