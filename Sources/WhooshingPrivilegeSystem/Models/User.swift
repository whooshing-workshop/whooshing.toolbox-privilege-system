import PgSQL
import Fluent
import Foundation
import Vapor
import DataConvertable
import Cryptos
import ErrorHandle

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
        from: \.$user,
        to: \.$role
    )                                                                       var roles: [Role]
    
    @Timestamp(fields.createdAt, on: .create)                               var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)                                var updateAt: Date!
    
    init() {}
}

extension User {
    @usableFromInline
    struct MIG: PGMigration, Sendable {
        @usableFromInline
        typealias DataModel = User
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}

//extension User: ModelAuthenticatable {
//    static let usernameKey = \User.$email
//    static let passwordHashKey = \User.$hashedPasswd
//
//    func verify(password: String) throws -> Bool {
//        // 客户端请求所提供的密码是 其对其用户明文密码进行单次哈希的结果
//        let passwd = try Base64String(password).dataRes.get()
//        // 对客户端密码设置后置盐，并再次哈希
//        let hashed = Crypto.hash(passwd + self.salt)
//        return try hashed == Base64String(self.hashedPasswd).dataRes.get()
//    }
//}
