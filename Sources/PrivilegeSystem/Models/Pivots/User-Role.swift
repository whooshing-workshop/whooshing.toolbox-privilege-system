import PgSQL

typealias UserRolePivot = Pivot<Pivots.UserRole>

extension Pivots {
    struct UserRole: PivotType {
        typealias PrimaryModel = User
        typealias SecondaryModel = Role
        
        static let foreignPrimaryName = "user"
        static let foreignSecondaryName = "role"
    }
}
