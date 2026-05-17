import PgSQL
import Policy
import Foundation

package extension Pivots {
    struct UserGroup: PivotType {
        package typealias PrimaryModel = User
        package typealias SecondaryModel = UGroup
        
        package static let foreignPrimaryName = "user"
        package static let foreignSecondaryName = "group"
    }
}

package class UserGroupPivot: CustomeIDPivot<Pivots.UserGroup>, PGModel, @unchecked Sendable {
    @Siblings(
        through: RoleUserInGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )
    var roles: [Role]
    
    @ID(key: .id)                               package var id: UUID?
    @Parent(fields.foreignPrimary)              var user: User
    @Parent(fields.foreignSecondary)            var group: UGroup
    @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
    
    package typealias MIG = DefaultMIG<UserGroupPivot>
}

extension UserGroupPivot: Hashable {
    package static func == (lhs: UserGroupPivot, rhs: UserGroupPivot) -> Bool {
        lhs.id == rhs.id &&
        lhs.$user.id == rhs.$user.id &&
        lhs.$group.id == rhs.$group.id &&
        lhs.createdAt == rhs.createdAt
    }
    
    package func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine($user.id)
        hasher.combine($group.id)
        hasher.combine(createdAt)
    }
}
