import PgSQL
import Policy
import Foundation

extension Pivots {
    struct UserGroup: PivotType {
        typealias PrimaryModel = User
        typealias SecondaryModel = UGroup
        
        static let foreignPrimaryName = "user"
        static let foreignSecondaryName = "group"
    }
}

class UserGroupPivot: CustomeIDPivot<Pivots.UserGroup>, PGModel, @unchecked Sendable {
    @Siblings(
        through: RoleUserInGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )
    var roles: [Role]
    
    @ID(key: .id)                               var id: UUID?
    @Parent(fields.foreignPrimary)              var user: User
    @Parent(fields.foreignSecondary)            var group: UGroup
    @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
    
    typealias MIG = DefaultMIG<UserGroupPivot>
}

extension UserGroupPivot: Hashable {
    static func == (lhs: UserGroupPivot, rhs: UserGroupPivot) -> Bool {
        lhs.id == rhs.id &&
        lhs.$user.id == rhs.$user.id &&
        lhs.$group.id == rhs.$group.id &&
        lhs.createdAt == rhs.createdAt
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine($user.id)
        hasher.combine($group.id)
        hasher.combine(createdAt)
    }
}
