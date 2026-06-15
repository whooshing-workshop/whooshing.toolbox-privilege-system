import PgSQL
import Policy
import Fluent

extension __SDBM {
    typealias RoleGroupPivot = Pivot<Pivots.RoleGroup>
}

extension __SDBM.Pivots {
    struct RoleGroup: PivotType {
        typealias PrimaryModel = __SDBM.Role
        typealias SecondaryModel = __SDBM.Group
        
        static let foreignPrimaryName = "role"
        static let foreignSecondaryName = "group"
        
        static let foreignPrimaryType = DatabaseSchema.DataType.uuid
    }
}
