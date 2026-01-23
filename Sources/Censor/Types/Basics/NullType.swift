import ErrorHandle
import Foundation

extension Censor {
    struct NullType: TypeDeclare {
        typealias RealType = Bool
        static let name = BasicType.null.rawValue
        let nullable: Bool
        
        init() {
            nullable = false
        }
        
        init(nullable: Bool) {
            fatalError("不应由此初始化 NullType")
        }
    }
    
    static let Null = NullType()
}
