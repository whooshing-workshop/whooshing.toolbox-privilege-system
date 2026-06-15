import PgSQL
import Policy
import Foundation
import FluentKit

public extension __SDBM.Pivots {
    struct UserGroup: PivotType {
        public typealias PrimaryModel = __SDBM.User
        public typealias SecondaryModel = __SDBM.Group
        
        public static let foreignPrimaryName = "user"
        public static let foreignSecondaryName = "group"
    }
}

public extension __SDBM {
    class UserGroupPivot: CustomeIDPivot<Pivots.UserGroup>, PGModel, @unchecked Sendable {
        @Siblings(
            through: RoleUserInGroupPivot.self,
            from: \.$secondaryModel,
            to: \.$primaryModel
        )
        var roles: [Role]
        
        @ID(key: .id)                               public var id: UUID?
        @Parent(fields.foreignPrimary)              var user: User
        @Parent(fields.foreignSecondary)            var group: Group
        @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
        
        public typealias MIG = DefaultMIG<UserGroupPivot>
    }
}
