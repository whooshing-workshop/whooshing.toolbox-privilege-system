import PgSQL
import Foundation
import Policy
import Cryptos
import Fluent

/// 数据库表 tokens 的映射类型
/// 该 tokens 表记录用户口令和用户凭据的对照，用于用户认证查询

public final class Token: PGModel, @unchecked Sendable {
    public static let name: String = "tokens"
    
    public struct Fields: PGFields {
        let id = PGField("id", .uuid)                               .primary
        let userId = PGField("user_id", .uuid)                      .required.unique.foreign(User.self, \.id, onDelete: .cascade)
        let credential = PGField("credential", .string)             .required.unique
        let token = PGField("token", .string)                       .required.unique
        let valid = PGField("valid", .bool)                         .required.def(true)     // 是否有效
        let expireAfter = PGField("expire_after", .int)             .required               // 过期时间，单位为分
        let createdAt = PGField("created_at", .datetime)            .required
        
        public init() {}
    }
    
    public static let fields: Fields = Fields()
    
    @ID(key: .id)                                                   public var id: UUID?
    
    @Parent(fields.userId)                                          var user: User
    @Field(fields.credential)                                       var credential: String
    @Field(fields.token)                                            var token: String
    @Field(fields.valid)                                            var valid: Bool
    @Field(fields.expireAfter)                                      var expireAfter: Int
    
    @Timestamp(fields.createdAt, on: .create)                       var createdAt: Date!
    
    public init() {}
    
    public typealias MIG = DefaultMIG<Token>
}

extension Token: Hashable {
    public static func == (lhs: Token, rhs: Token) -> Bool {
        lhs.id == rhs.id &&
        lhs.$user.id == rhs.$user.id &&
        lhs.credential == rhs.credential &&
        lhs.token == rhs.token &&
        lhs.valid == rhs.valid &&
        lhs.expireAfter == rhs.expireAfter &&
        lhs.createdAt == rhs.createdAt
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine($user.id)
        hasher.combine(credential)
        hasher.combine(token)
        hasher.combine(valid)
        hasher.combine(expireAfter)
        hasher.combine(createdAt)
    }
}

extension Token: ModelCredentialsAuthenticatable {
    public static let usernameKey: KeyPath<Token, Field<String>> = \Token.$credential
    public static let passwordHashKey: KeyPath<Token, Field<String>> = \Token.$token
    public func verify(password: String) throws -> Bool { password == self.token }
}
