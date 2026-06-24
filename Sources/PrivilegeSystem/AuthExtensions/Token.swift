import Vapor
import PrivilegeModuleExtended

// MARK: - Authenticate

extension QToken: Authenticatable {}

public struct TokenAuthenticator: CredentialsAuthenticator {
    public init() {}
    
    public func authenticate(credentials: AuthorizationToken, for request: Request) -> EventLoopFuture<Void> {
        __SDBM.Token.query(on: request.db)
            .filter(\.$credential == credentials.credential)
            .first()
            .withError(PrivilegeSystem.Errcase.tokenAuthFailed, "从数据库中查询 Token 发生错误", category: .internal)
            .flatMapThrowing
        { t throws(PrivilegeSystem.Errcase.ErrType) in
            guard let token = t else {
                throw PrivilegeSystem.Errcase.tokenAuthFailed.d("凭据不存在", category: .external(suggestions: ["请提供有效的凭据"]))
            }
            guard
                try required(throws: PrivilegeSystem.Errcase.tokenAuthFailed, "密钥比对时发生错误", category: .internal, {
                    try token.verify(password: credentials.tokenHashed)
                })
            else {
                throw PrivilegeSystem.Errcase.tokenAuthFailed.d("凭据无效或已撤销", category: .external(suggestions: ["清提供有效的凭据"]))
            }
            
            let tokenDTO = try required(throws: PrivilegeSystem.Errcase.tokenAuthFailed, "从数据库实例转为 DTO 失败", category: .internal) {
                try QToken.make(from: token).get()
            }
            
            return tokenDTO
        }.flatMap { token in
            request.db.eventLoop.bridge { () throws(PrivilegeSystem.Errcase.ErrType) in
                try await required(throws: PrivilegeSystem.Errcase.tokenAuthFailed, "取得 Token 关联 User 对象失败", category: .internal) {
                    try await token.$user.load(on: request).get()
                }
                request.auth.login(token)
            }
        }.vaporlized
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
