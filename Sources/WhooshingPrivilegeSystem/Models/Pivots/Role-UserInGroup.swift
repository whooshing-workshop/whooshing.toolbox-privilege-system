import PgSQL
import Fluent
import Foundation

final class RoleUserInGroupPivot: PGModel, @unchecked Sendable {
    
    static let name = "role_user_in_group_map"
    
    struct Fields: PGFields {
        
        let id = PGField("id", .uuid)                           .primary
        let roleId = PGField("role_id", .uuid)                  .required.foreign(Role.self, \.id, onDelete: .cascade)
        let userInGroupId = PGField("user_in_group_id", .uuid)  .required.foreign(UserGroupPivot.self, \.id, onDelete: .cascade)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: Int?
    
    @Parent(fields.roleId)                          var role: Role
    @Parent(fields.userInGroupId)                   var userGroupMap: UserGroupPivot
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension RoleUserInGroupPivot {
    @usableFromInline
    struct MIG: PGMigration, Sendable {
        @usableFromInline
        typealias DataModel = RoleUserInGroupPivot
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
