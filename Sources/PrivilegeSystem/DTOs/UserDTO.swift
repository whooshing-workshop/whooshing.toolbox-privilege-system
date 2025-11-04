import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos

extension User: ModelAuthenticatable {
    static let usernameKey: KeyPath<User, Field<String>> = \User.$email
    static let passwordHashKey: KeyPath<User, Field<String>> = \User.$hashedPasswd
    
    func verify(password: String) throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        // 客户端请求所提供的密码是 其对其用户明文密码进行单次哈希的结果
        let passwd = try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .parameter) {
            try Base64String(password).dataRes.get()
        }
        // 对客户端密码设置后置盐，并再次哈希
        let hashed = Crypto.hash(passwd + self.salt)
        return try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .parameter) {
            try hashed == Base64String(self.hashedPasswd).dataRes.get()
        }
    }
}

public struct UserDTO: Sendable {
    public var id: UUID
    public var email: String
    public let createdAt: Date
    public let updateAt: Date

    init(from user: User) {
        self.id = user.id!
        self.email = user.email
        self.createdAt = user.createdAt
        self.updateAt = user.updateAt
    }
}
