import PgSQL
import Fluent
import Foundation

final class UserRolePivot: PGModel, @unchecked Sendable {
    
    static let name = "user_role_map"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let userId = PGField("user_id", .uuid)                  .required.unique(composite: name + ".pivot").foreign(User.self, \.id, onDelete: .cascade)
        let roleId = PGField("role_id", .uuid)                  .required.unique(composite: name + ".pivot").foreign(Role.self, \.id, onDelete: .cascade)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: Int?
    
    @Parent(fields.userId)                          var user: User
    @Parent(fields.roleId)                          var role: Role
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension UserRolePivot {
    @usableFromInline
    struct MIG: TdeMIG, Sendable {
        @usableFromInline
        typealias DataModel = UserRolePivot
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
