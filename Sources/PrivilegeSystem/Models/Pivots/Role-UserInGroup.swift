import PgSQL
import Censor

typealias RoleUserInGroupPivot = Pivot<Pivots.RoleUserInGroup>

extension Pivots {
    struct RoleUserInGroup: PivotType {
        typealias PrimaryModel = Role
        typealias SecondaryModel = UserGroupPivot
        
        static let foreignPrimaryName = "role"
        static let foreignSecondaryName = "user_in_group"
    }
}
