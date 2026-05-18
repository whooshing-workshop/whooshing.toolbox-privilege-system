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
