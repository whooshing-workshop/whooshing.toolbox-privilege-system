import ErrorHandle
import Foundation

public extension Censor {
    struct TrueType<T>: TypeDeclare where T: TypeDeclare {
        public typealias RealType = T.Type
        public static var name: String { "\(T.name).Type" }
        public let nullable: Bool
        
        public var properties: [String : PropertyDeclare] {
            T.staticProperties
        }
        
        public var functions: [String: FunctionDeclare] {
            T.staticFunctions
        }
        
        public static var propertyActions: [String: ExecutableAction] { T.staticPropertieActions }
        public static var functionActions: [String: ExecutableAction] { T.staticFunctionActions }
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}

extension ISO8601DateFormatter: @unchecked @retroactive Sendable {}
