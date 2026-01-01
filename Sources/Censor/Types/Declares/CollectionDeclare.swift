extension Censor {
    public protocol CollectionTypeDeclare: TypeDeclare where RealType: Collection, RealType.Element == ElementType.RealType {
        associatedtype ElementType: TypeDeclare
        
//        func item(at index: RealType.Index, in value: Value) -> ElementType.RealType
    }
}

//public extension Censor.CollectionTypeDeclare {
//    func item(at index: RealType.Index, in value: Censor.Value) -> ElementType.RealType {
//        let v = realType(of: value)
//        return v[index]
//    }
//}
