import PgSQL
import Foundation
import ACL

final class Role: PGModel, @unchecked Sendable {
    
    static let name = "roles"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let aclId = PGField("acl_id", .uuid)                    .required.foreign(ACL.self, \.id, onDelete: .cascade)
        let ast = PGField("ast", .json)                         .required.cons(.sql(.default("{}")))
        let expression = PGField("expression", .string)         .required
        let name = PGField("name", .string)                     .required
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
    @Parent(fields.aclId)                           var acl: ACL
    @Field(fields.ast)                              var ast: AST
    @Field(fields.expression)                       var expression: String
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
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
    
    typealias MIG = DefaultMIG<Role>
}
