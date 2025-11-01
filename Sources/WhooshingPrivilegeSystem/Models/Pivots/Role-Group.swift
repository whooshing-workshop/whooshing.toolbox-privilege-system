import PgSQL
import Fluent
import Foundation

final class RoleGroupPivot: PGModel, @unchecked Sendable {
    
    static let name = "role_group_map"
    
    struct Fields: PGFields {
        
        let id = PGField("id", .uuid)                           .primary
        let roleId = PGField("role_id", .uuid)                  .required.foreign(Role.self, \.id, onDelete: .cascade)
        let groupId = PGField("group_id", .uuid)                .required.foreign(UGroup.self, \.id, onDelete: .cascade)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: Int?
    
    @Parent(fields.roleId)                          var role: Role
    @Parent(fields.groupId)                         var group: UGroup
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension RoleGroupPivot {
    @usableFromInline
    struct MIG: PGMigration, Sendable {
        @usableFromInline
        typealias DataModel = RoleGroupPivot
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
