import PgSQL
import Fluent
import Foundation
import ACL

final class UGroup: PGModel, @unchecked Sendable {
    
    static let name = "groups"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let parentId = PGField("parent_id", .uuid)              .foreign(UGroup.self, .id, onDelete: .cascade)
        let name = PGField("name", .string)                     .required
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
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
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
    
    typealias MIG = DefaultMIG<UGroup>
}
