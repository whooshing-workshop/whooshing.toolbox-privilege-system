import PgSQL
import Policy
import Fluent

extension __SDBM {
    typealias RoleUserInGroupPivot = Pivot<Pivots.RoleUserInGroup>
}

extension __SDBM.Pivots {
    struct RoleUserInGroup: PivotType {
        typealias PrimaryModel = __SDBM.Role
        typealias SecondaryModel = __SDBM.UserGroupPivot
        
        static let foreignPrimaryName = "role"
        static let foreignSecondaryName = "user_in_group"
        
        static let foreignPrimaryType = DatabaseSchema.DataType.uuid
    }
}
