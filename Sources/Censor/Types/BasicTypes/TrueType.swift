import ErrorHandle
import Foundation

public extension Censor {
    struct TrueType<T>: TypeDeclare where T: TypeDeclare {
        public typealias RealType = T.Type
        public static var name: String { "TrueType<\(T.name)>" }
        public let nullable: Bool
        
        public static var properties: [String : Property] {
            T.staticProperties
        }
        
        public static var functions: [String: Function] {
            T.staticFunctions
        }
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}

extension ISO8601DateFormatter: @unchecked @retroactive Sendable {}
