import PgSQL
import Foundation
import Fluent
import PrivilegeModule
import DTOBuilder

public extension __SDBM {
    final class Role: PGModel, @unchecked Sendable {
        
        public static let name = "roles"
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let name = PGField("name", .string)                         .required
            let description = PGField("description", .string)
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public static let fields = Fields()
        
        @ID(key: .id)                                   public var id: UUID?
        
        @Field(fields.name)                             var name: String
        @Field(fields.description)                      var description: String?
        
        @Siblings(
            through: UserRolePivot.self,
            from: \.$secondaryModel,
            to: \.$primaryModel
        )                                               var users: [User]
        @Siblings(
            through: RoleGroupPivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                               var groups: [Group]
        @Siblings(
            through: RoleUserInGroupPivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                               var usersInGroup: [UserGroupPivot]
        @Children(
            for: \RolePolicy.$parent
        )                                               var policies: [RolePolicy]
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
        
        public init() {}
        
        func fill() -> Self {
            self.$users.fromId = self.id
            self.$groups.fromId = self.id
            self.$usersInGroup.fromId = self.id
            self.$policies.fromId = self.id
            return self
        }
        
        public typealias MIG = DefaultMIG<Role>
    }
}
