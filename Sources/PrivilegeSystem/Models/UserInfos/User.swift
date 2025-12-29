import PgSQL
import Foundation
import Censor

/// 数据库表 users 的映射类型
/// 记录所有已注册的用户

final class User: PGModel, @unchecked Sendable {
    static let name: String = "users"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                               .primary
        let email = PGField("email", .string)                       .required.unique
        let hashedPasswd = PGField("hashed_passwd", .string)        .required
        let key = PGField("key", .data)                             .required
        let salt = PGField("salt", .data)                           .required
        let createdAt = PGField("create_at", .string)               .required
        let updateAt = PGField("update_at", .string)                .required
    }
    
    static let fields = Fields()
    
    @ID(key: .id)                                                           var id: UUID?
    
    @Field(fields.email)                                                    var email: String
    @Field(fields.hashedPasswd)                                             var hashedPasswd: String
    @Field(fields.key)                                                      var key: Data
    @Field(fields.salt)                                                     var salt: Data
    
    @OptionalChild(for: \Token.$user)                                       var token: Token!
    @Siblings(
        through: UserGroupPivot.self,
        from: \.$user,
        to: \.$group
    )                                                                       var groups: [UGroup]
    @Siblings(
        through: UserRolePivot.self,
        from: \.$primaryModel,
        to: \.$secondaryModel
    )                                                                       var roles: [Role]
    @Siblings(
        through: UserDomainPivot.self,
        from: \.$primaryModel,
        to: \.$secondaryModel
    )                                                                       var domains: [Domain]
    
    @Timestamp(fields.createdAt, on: .create)                               var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)                                var updateAt: Date!
    
    init() {}
    
    typealias MIG = DefaultMIG<User>
}
