import PgSQL
import Policy
import Fluent

extension PrivilegeModule {
    typealias PrivilegeResourcePivot = Pivot<PrivilegeResource>
    
    struct PrivilegeResource: PivotType {
        typealias PrimaryModel = Privilege
        typealias SecondaryModel = AnyResource
        
        static var foreignPrimaryName: String { "privilege" }
        static var foreignSecondaryName: String { "resource" }
        
        static var foreignPrimaryType: DatabaseSchema.DataType { .int64 }
    }
}
