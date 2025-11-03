import PgSQL

extension Pivots {
    struct UserGroup: PivotType {
        typealias PrimaryModel = User
        typealias SecondaryModel = UGroup
        
        static let foreignPrimaryName = "user"
        static let foreignSecondaryName = "group"
    }
}

class UserGroupPivot: Pivot<Pivots.UserGroup>, @unchecked Sendable {
    @Siblings(
        through: RoleUserInGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )
    var roles: [Role]
    
    @Parent(fields.foreignPrimary)                  var user: User
    @Parent(fields.foreignSecondary)                var group: UGroup
    
    typealias MIG = DefaultMIG<UserGroupPivot>
}
