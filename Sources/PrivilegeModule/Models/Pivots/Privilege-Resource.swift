import DTOBuilder

public extension PrivilegeModule.__DBM {
    typealias PrivilegeAnyResourcePivot = Pivot<PrivilegeAnyResource>
    
    struct PrivilegeAnyResource: PivotType {
        public typealias PrimaryModel = Privilege
        public typealias SecondaryModel = __SDBM.AnyResource
        
        public static var foreignPrimaryName: String { "privilege" }
        public static var foreignSecondaryName: String { "resource" }
        
        public static var foreignPrimaryType: DatabaseSchema.DataType { .uuid }
    }
}

public extension PrivilegeModule.__DBM {
    typealias PrivilegeResourcePivot<T: Resource> = Pivot<PrivilegeResource<T>> where T.ResourceType == ResourceList
    
    struct PrivilegeResource<T: Resource>: PivotType where T.ResourceType == ResourceList {
        public typealias PrimaryModel = Privilege
        public typealias SecondaryModel = ResourceModel<T>
        
        public static var foreignPrimaryName: String { "privilege" }
        public static var foreignSecondaryName: String { "resource" }
        
        public static var foreignPrimaryType: DatabaseSchema.DataType { .uuid }
    }
}
