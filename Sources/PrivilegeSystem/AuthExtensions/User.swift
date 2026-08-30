import Vapor
import PrivilegeModuleExtended

// MARK: - ModelAuthenticatable

extension __SDBM.User: ModelAuthenticatable {
    public static let usernameKey: KeyPath<__SDBM.User, Field<String>> = \.$email
    public static let passwordHashKey: KeyPath<__SDBM.User, Field<String>> = \.$hashedPassword
    
    public func verify(password: String) throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        // 客户端请求所提供的密码是 其对其用户明文密码进行单次哈希的结果
        let passwd = try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "所输入的密码有误，无法进行 Base64 转换", category: .external(suggestions: ["请提供正确的账号密码"], userdata: .init(HTTPResponseStatus.unauthorized))) {
            try Base64String(password).dataRes.get()
        }
        // 对客户端密码设置后置盐，并再次哈希
        let hashed = Crypto.hash(passwd + self.salt)
        return try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .external(suggestions: ["请提供正确的账号密码"], userdata: .init(HTTPResponseStatus.unauthorized))) {
            try hashed == Base64String(self.hashedPassword).dataRes.get()
        }
    }
}

