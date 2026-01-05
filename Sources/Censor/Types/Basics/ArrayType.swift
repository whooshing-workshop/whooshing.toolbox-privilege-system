import ErrorHandle
import Foundation

extension Censor {
    struct ArrayType<Element>: CollectionTypeDeclare where Element: TypeDeclare {
        typealias RealType = [Element.RealType]
        typealias ElementType = Element
        
        static var name: String { "Array<\(Element.name)>" }
        let nullable: Bool
        
        let properties: [String : PropertyDeclare] = [
            "count": .init(returns: IntegerType(nullable: false)),
            "first": .init(returns: Element(nullable: true)),
            "last": .init(returns: Element(nullable: true))
        ]
        
        static var propertyActions: [String : ExecutableAction] {
            [
                "count": .init {
                    .succ(Int64($0[0].cast(as: [Any?].self).count))
                },
                "first": .init {
                    .succ($0[0].cast(as: [Any].self).first)
                },
                "last": .init {
                    .succ($0[0].cast(as: [Any].self).last)
                }
            ]
        }
        
        init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}
