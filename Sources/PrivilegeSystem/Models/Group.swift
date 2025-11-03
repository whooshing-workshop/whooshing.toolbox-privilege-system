import PgSQL
import Fluent
import Foundation

final class UGroup: PGModel, @unchecked Sendable {
    
    static let name = "groups"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let name = PGField("name", .string)                     .required
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
    @Field(fields.name)                             var name: String
    @Field(fields.description)                      var description: String?
    
    @Siblings(
        through: UserGroupPivot.self,
        from: \.$group,
        to: \.$user
    )                                               var users: [User]
    @Siblings(
        through: RoleGroupPivot.self,
        from: \.$group,
        to: \.$role
    )                                               var groupRoles: [Role]
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension UGroup {
    @usableFromInline
    struct MIG: TdeMIG, Sendable {
        @usableFromInline
        typealias DataModel = UGroup
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
