import PgSQL
import Policy
import Foundation
import FluentKit

public extension Pivots {
    struct UserGroup: PivotType {
        public typealias PrimaryModel = User
        public typealias SecondaryModel = UGroup
        
        public static let foreignPrimaryName = "user"
        public static let foreignSecondaryName = "group"
    }
}

public class UserGroupPivot: CustomeIDPivot<Pivots.UserGroup>, PGModel, @unchecked Sendable {
    @Siblings(
        through: RoleUserInGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )
    var roles: [Role]
    
    @ID(key: .id)                               public var id: UUID?
    @Parent(fields.foreignPrimary)              var user: User
    @Parent(fields.foreignSecondary)            var group: UGroup
    @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
    
    public typealias MIG = DefaultMIG<UserGroupPivot>
}
