import PgSQL
import Foundation
import Policy
import Fluent

public final class Role: PGModel, @unchecked Sendable {
    
    public static let name = "roles"
    
    public struct Fields: PGFields {
        let id = PGField("id", .int64)                          .primary
        let name = PGField("name", .string)                     .required
        let description = PGField("description", .string)
        let createdAt = PGField("created_at", .datetime)           .required
        let updatedAt = PGField("updated_at", .datetime)           .required
        
        public init() {}
    }
    
    public static let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: Int64?
    
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
    )                                               var groups: [UGroup]
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
    
    public typealias MIG = DefaultMIG<Role>
}

extension Role: Hashable {
    public static func == (lhs: Role, rhs: Role) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
}
