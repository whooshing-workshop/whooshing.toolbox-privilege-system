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

/// 用于用户通过主服务器验证时使用，Token 的加密机制为 [密钥 hash] + [明文凭据]
/// 仅用于通讯通道已经可靠加密的情况
extension __SDBM.Token: ModelCredentialsAuthenticatable {
    public static let usernameKey: KeyPath<__SDBM.Token, Field<String>> = \.$credential
    public static let passwordHashKey: KeyPath<__SDBM.Token, Field<String>> = \.$token
    
    // 用户发来的 password(即 token) 是 [密钥 hash]
    public func verify(password: String) throws -> Bool {
        // 取得用户传来 tokenHashed 的字节码
        let userTokenData = try required(throws: PrivilegeSystem.Errcase.tokenVerifyFailed, "用户口令并非 Base64 编码", category: .external()) {
            try Base64String(password).dataRes.get()
        }
        
        return try verify(passwordData: userTokenData)
    }
    
    // 用户发来的 password(即 token) 是 [密钥 hash]
    internal func verify(passwordData: Data) throws -> Bool {
        // 检查是否有效
        guard self.valid == true else {
            throw PrivilegeSystem.Errcase.tokenVerifyFailed.d("用户口令无效", category: .external(suggestions: ["请提供有效的登录口令"]))
        }
        
        // 检查是否已过期
        let expireDate = self.createdAt.addingTimeInterval(TimeInterval(self.expireAfter * 60))
        guard Date() < expireDate else {
            throw PrivilegeSystem.Errcase.tokenVerifyFailed.d("用户凭据已过期", category: .external(suggestions: ["请提供有效的登录口令"]))
        }
        
        // 取得 db 密钥的字节码，并对其进行 hash，以进行接下来的比对
        let dbTokenData = try required(throws: PrivilegeSystem.Errcase.tokenVerifyFailed, "对数据库中的口令哈希失败", metadata: ["credential": .data(self.credential)], category: .internal) {
            try Crypto.hash(Base64String(self.token)).get()
        }
        
        return passwordData == dbTokenData
    }
}
