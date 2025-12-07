import PgSQL
import Foundation
import ACL
import Cryptos
import Fluent

/// 数据库表 tokens 的映射类型
/// 该 tokens 表记录用户口令和用户凭据的对照，用于用户认证查询

final class Token: PGModel, @unchecked Sendable {
    static let name: String = "tokens"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                               .primary
        let userId = PGField("user_id", .uuid)                      .required.unique.foreign(User.self, \.id, onDelete: .cascade)
        let credential = PGField("credential", .string)             .required.unique
        let token = PGField("token", .string)                       .required.unique
        let valid = PGField("valid", .bool)                         .required.def(true)     // 是否有效
        let expireAfter = PGField("expire_after", .int)             .required               // 过期时间，单位为分
        let createdAt = PGField("create_at", .string)               .required
    }
    
    static let fields: Fields = Fields()
    
    @ID(key: .id)                                                   var id: UUID?
    
    @Parent(fields.userId)                                          var user: User
    @Field(fields.credential)                                       var credential: String
    @Field(fields.token)                                            var token: String
    @Field(fields.valid)                                            var valid: Bool
    @Field(fields.expireAfter)                                      var expireAfter: Int
    
    @Timestamp(fields.createdAt, on: .create)                       var createdAt: Date!
    
    init() {}
    
    typealias MIG = DefaultMIG<Token>
}

extension Token: ModelCredentialsAuthenticatable {
    static let usernameKey: KeyPath<Token, Field<String>> = \Token.$credential
    static let passwordHashKey: KeyPath<Token, Field<String>> = \Token.$token
    func verify(password: String) throws -> Bool { password == self.token }
}
