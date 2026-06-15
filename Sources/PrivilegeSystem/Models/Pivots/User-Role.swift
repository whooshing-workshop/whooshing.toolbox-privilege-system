import PgSQL
import Policy
import Fluent

extension __SDBM {
    typealias UserRolePivot = Pivot<Pivots.UserRole>
}

extension __SDBM.Pivots {
    struct UserRole: PivotType {
        typealias PrimaryModel = __SDBM.User
        typealias SecondaryModel = __SDBM.Role
        
        static let foreignPrimaryName = "user"
        static let foreignSecondaryName = "role"
        
        static let foreignSecondaryType = DatabaseSchema.DataType.uuid
    }
}
