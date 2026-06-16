import PgSQL
import Policy
import Fluent

public extension __SDBM {
    typealias RoleUserInGroupPivot = Pivot<Pivots.RoleUserInGroup>
}

public extension __SDBM.Pivots {
    struct RoleUserInGroup: PivotType {
        public typealias PrimaryModel = __SDBM.Role
        public typealias SecondaryModel = __SDBM.UserGroupPivot
        
        public static let foreignPrimaryName = "role"
        public static let foreignSecondaryName = "user_in_group"
        
        public static let foreignPrimaryType = DatabaseSchema.DataType.uuid
    }
}
