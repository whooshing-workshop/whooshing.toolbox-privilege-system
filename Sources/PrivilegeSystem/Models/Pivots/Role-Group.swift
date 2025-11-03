import PgSQL

typealias RoleGroupPivot = Pivot<Pivots.RoleGroup>

extension Pivots {
    struct RoleGroup: PivotType {
        typealias PrimaryModel = Role
        typealias SecondaryModel = UGroup
        
        static let foreignPrimaryName = "role"
        static let foreignSecondaryName = "group"
    }
}
