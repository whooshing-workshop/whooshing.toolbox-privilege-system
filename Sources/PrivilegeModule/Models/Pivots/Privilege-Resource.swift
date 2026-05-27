import PgSQL
import Policy
import Fluent
import ResourceMacros

extension PrivilegeModule {
    typealias PrivilegeAnyResourcePivot = Pivot<PrivilegeAnyResource>
    
    struct PrivilegeAnyResource: PivotType {
        typealias PrimaryModel = Privilege
        typealias SecondaryModel = AnyResource
        
        static var foreignPrimaryName: String { "privilege" }
        static var foreignSecondaryName: String { "resource" }
        
        static var foreignPrimaryType: DatabaseSchema.DataType { .uuid }
    }
}

extension PrivilegeModule {
    typealias PrivilegeResourcePivot<T: Resource> = Pivot<PrivilegeResource<T>> where T.ResourceType == ResourceList
    
    struct PrivilegeResource<T: Resource>: PivotType where T.ResourceType == ResourceList {
        typealias PrimaryModel = Privilege
        typealias SecondaryModel = ResourceModel<T>
        
        static var foreignPrimaryName: String { "privilege" }
        static var foreignSecondaryName: String { "resource" }
        
        static var foreignPrimaryType: DatabaseSchema.DataType { .uuid }
    }
}
