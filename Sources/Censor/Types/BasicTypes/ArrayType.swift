import ErrorHandle
import Foundation

public extension Censor {
    struct ArrayType<T>: CollectionTypeDeclare where T: TypeDeclare {
        public typealias RealType = [T.RealType]
        public typealias ElementType = T
        
        public static var name: String { "Array<\(T.name)>" }
        public let nullable: Bool
        
        public let properties: [String : Property] = [
            "count": .init {
                Return { IntegerType(nullable: false) }
                Action { .succ(Int64($0.cast(as: [Any?].self).count)) }
            },
            "first": .init {
                Return { T(nullable: true) }
                Action { .succ($0.cast(as: [Any].self).first) }
            },
            "last": .init {
                Return { T(nullable: true) }
                Action { .succ($0.cast(as: [Any].self).last) }
            }
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}

//static let typeDetect = RelatedReturn {
//    guard let arr = $0.content as? [Any?] else {
//        preconditionFailure("传入的值并非数组类型")
//    }
//    
//    guard let first = arr.first else {
//        return .failure(.arrayTypeDetectFailed, "类型不合法，无法推断类型", category: .external)
//    }
//    
//    var type: (any TypeDeclare)? = nil
//    
//    for item in arr {
//        let t = getType(of: item)
//        if type == nil && t != nil {
//            type = t
//        }
//        if type != nil && t != nil && Swift.type(of: t!).name != Swift.type(of: type!).name {
//            type = AnyType(nullable: false)
//        }
//    }
//    
//    guard let res = type else {
//        return .failure(.arrayTypeDetectFailed, "无法推断类型，请至少指定一个有效值", category: .external)
//    }
//    
//    return .success(res)
//}
