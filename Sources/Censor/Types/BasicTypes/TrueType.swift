import ErrorHandle
import Foundation

public extension Censor {
    struct TrueType: TypeDeclare {
        public typealias RealType = String
        public static let name = "TrueType"
        public let nullable: Bool
        public let type: any TypeDeclare.Type
        
        public var properties: [String : PropertyDeclare] {
            type.staticProperties
        }
        
        public var functions: [String: FunctionDeclare] {
            type.staticFunctions
        }
        
        public init(nullable: Bool) {
            self = Self.init(nullable: nullable, type: AnyType.self)
        }
        
        public init(nullable: Bool, type: any TypeDeclare.Type) {
            self.nullable = nullable
            self.type = type
        }
    }
}
