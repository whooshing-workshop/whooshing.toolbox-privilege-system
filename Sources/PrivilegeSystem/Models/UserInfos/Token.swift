import Cryptos
import Foundation
import DTOBuilder

/// 数据库表 tokens 的映射类型
/// 该 tokens 表记录用户口令和用户凭据的对照，用于用户认证查询

public extension __SDBM{
    final class Token: PGModel, @unchecked Sendable {
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
}

extension __SDBM.Token: ModelCredentialsAuthenticatable {
    public static let usernameKey: KeyPath<__SDBM.Token, Field<String>> = \.$credential
    public static let passwordHashKey: KeyPath<__SDBM.Token, Field<String>> = \.$token
    public func verify(password: String) throws -> Bool { password == self.token }
}
