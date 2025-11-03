import PgSQL
import Fluent
import Foundation

final class UserGroupPivot: PGModel, @unchecked Sendable {
    
    static let name = "user_group_map"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let userId = PGField("user_id", .uuid)                  .required.unique(composite: name + ".pivot").foreign(User.self, \.id, onDelete: .cascade)
        let groupId = PGField("group_id", .uuid)                .required.unique(composite: name + ".pivot").foreign(UGroup.self, \.id, onDelete: .cascade)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: Int?
    
    @Parent(fields.userId)                          var user: User
    @Parent(fields.groupId)                         var group: UGroup
    
    @Siblings(
        through: RoleUserInGroupPivot.self,
        from: \.$userGroupMap,
        to: \.$role
    )                                               var roles: [Role]
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension UserGroupPivot {
    @usableFromInline
    struct MIG: TdeMIG, Sendable {
        @usableFromInline
        typealias DataModel = UserGroupPivot
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
