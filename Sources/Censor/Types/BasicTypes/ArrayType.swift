//import ErrorHandle
//import Foundation
//
//public extension Censor {
//    struct ArrayType: CollectionTypeDeclare {
//        public typealias RealType = [Any]
//        public typealias ElementType = AnyType
//        
//        public static let name = "Array"
//        public let nullable: Bool
//        public let elementType: any TypeDeclare
//        
//        public let properties: [String : PropertyDeclare]
//        
//        public static let propertyActions: [String : ExecutableAction] = [
//            "count": .init {
//                .succ(Int64($0.first!.cast(as: [Any?].self).count))
//            },
//            "first": .init {
//                .succ($0.first!.cast(as: [Any].self).first)
//            },
//            "last": .init {
//                .succ($0.first!.cast(as: [Any].self).last)
//            }
//        ]
//        
//        public func detectAndSetElementType(by types: [(any TypeDeclare)?]) -> Res<Self, Errcase> {
//            var type: (any TypeDeclare)? = nil
//            var nullable: Bool? = nil
//            for t in types {
//                if type == nil, let t = t {
//                    type = t
//                    nullable = t.nullable
//                }
//                if let finalType = type, let t = t {
//                    if Swift.type(of: t).name == Swift.type(of: finalType).name {
//                        type = t
//                    } else {
//                        type = AnyType(nullable: false)
//                    }
//                    
//                    nullable = t.nullable != finalType.nullable || t.nullable == true
//                }
//                if
//                    let t = type,
//                    Swift.type(of: t).name == AnyType.name,
//                    nullable == true
//                {
//                    break
//                }
//            }
//            
//            guard let res = type, let canBeNull = nullable else {
//                return .failure(.arrayTypeDetectFailed, "无法推断类型，请至少指定一个有效值", category: .external)
//            }
//        
//            return .success(.init(nullable: false, elementType: res.set(nullable: canBeNull)))
//        }
//        
//        public init(nullable: Bool) {
//            self = Self.init(nullable: nullable, elementType: AnyType(nullable: true))
//        }
//        
//        private init(nullable: Bool, elementType: any TypeDeclare) {
//            self.nullable = nullable
//            self.elementType = elementType
//            self.properties = [
//                "count": .init { IntegerType(nullable: false) },
//                "first": .init { elementType },
//                "last": .init { elementType }
//            ]
//        }
//    }
//}

import ErrorHandle
import Foundation

public extension Censor {
    struct ArrayType<Element>: CollectionTypeDeclare where Element: TypeDeclare {
        public typealias RealType = [Element.RealType]
        public typealias ElementType = Element
        
        public static var name: String { "Array<\(Element.name)>" }
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "count": .init(returns: IntegerType(nullable: false)),
            "first": .init(returns: Element(nullable: true)),
            "last": .init(returns: Element(nullable: true))
        ]
        
        public static var propertyActions: [String : ExecutableAction] {
            [
                "count": .init {
                    .succ(Int64($0.first!.cast(as: [Any?].self).count))
                },
                "first": .init {
                    .succ($0.first!.cast(as: [Any].self).first)
                },
                "last": .init {
                    .succ($0.first!.cast(as: [Any].self).last)
                }
            ]
        }
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
