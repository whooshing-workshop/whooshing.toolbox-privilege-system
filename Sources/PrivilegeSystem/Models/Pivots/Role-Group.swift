import PgSQL
import Policy
import Fluent
import DTOBuilder

public extension __SDBM {
    typealias RoleGroupPivot = Pivot<Pivots.RoleGroup>
}

public extension __SDBM.Pivots {
    struct RoleGroup: PivotType {
        public typealias PrimaryModel = __SDBM.Role
        public typealias SecondaryModel = __SDBM.Group
        
        public static let foreignPrimaryName = "role"
        public static let foreignSecondaryName = "group"
        
        public static let foreignPrimaryType = DatabaseSchema.DataType.uuid
    }
}
