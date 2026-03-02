import PgSQL
import Fluent
import Foundation
import Policy

public final class UGroup: PGModel, @unchecked Sendable {
    
    public static let name = "groups"
    
    public struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let parentId = PGField("parent_id", .uuid)              .foreign(UGroup.self, .id, onDelete: .cascade)
        let name = PGField("name", .string)                     .required
        let description = PGField("description", .string)
        let createdAt = PGField("created_at", .datetime)           .required
        let updatedAt = PGField("updated_at", .datetime)           .required
        
        public init() {}
    }
    
    
    public static let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @OptionalParent(fields.parentId)                var parent: UGroup?
    
    @Field(fields.name)                             var name: String
    @Field(fields.description)                      var description: String?
    
    @Children(for: \Path.$descendant)               var descendants: [Path]
    @Children(for: \Path.$ancestor)                 var ancestors: [Path]
    @Siblings(
        through: UserGroupPivot.self,
        from: \.$group,
        to: \.$user
    )                                               var users: [User]
    @Siblings(
        through: RoleGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )                                               var groupRoles: [Role]
    @Siblings(
        through: DomainGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )                                               var domains: [Domain]
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
    
    public init() {}
    
    public typealias MIG = DefaultMIG<UGroup>
}
