import Foundation
import Cryptos
import Fluent
import Vapor
import DataConvertable
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    /// 权限服务层，提供权限相关的业务接口
    public struct AccountController: Sendable {
        private let db: PrivilegeSystem.PGDatabase
        private let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
        
        func register(
            email: String, 
            passwordHashed: String
        ) -> EventLoopRes<UserDTO, Errcase> {
            eventLoop.submitResult { () throws(Errcase.ErrType) -> User in
                let user = User()
                user.email = email
                // 为用户创建一个用户加密密钥
                user.key = Crypto.Symm.makeKey().data
                user.salt = Crypto.randomDataGenerate()

                // 对用户密码进行第二重加盐哈希
                let passwd = try required(throws: Errcase.userRegisterFailed, "对密码进行二次哈希时失败", category: .internel) {
                    try Crypto.hash(Base64String(passwordHashed).dataRes.get() + user.salt)
                }
                user.hashedPasswd = passwd.base64EncodedString()
                return user
            }.flatMap { user in
                user.save(on: db)
                    .withError(Errcase.userRegisterFailed, "将用户存入数据库时失败", category: .internel)
                    .map { user.id }
            }.flatMap { id in
                User.find(id, on: db)
                    .withError(Errcase.userRegisterFailed, "重新加载用户失败", category: .internel)
                    .flatMapThrowing
                { res throws(Errcase.ErrType) in
                    guard let user = res else {
                        throw .init(.userRegisterFailed, "用户未保存在数据库中，未知错误", category: .internel)
                    }
                    return UserDTO(from: user)
                }
            }
        }
        
        func login(
            email: String,
            password: String
        ) -> EventLoopRes<TokenDTO, Errcase> {
            User.query(on: db)
                .filter(\.$email == email)
                .first()
                .withError(Errcase.userLoginFailed, "用户不存在", category: .parameter)
                .flatMapThrowing
            { (res) throws(Errcase.ErrType) -> (User, UUID, Token) in
                guard let user = res else {
                    throw Errcase.userLoginFailed.d("用户不存在", category: .parameter)
                }
                
                let userId = try required(throws: Errcase.userLoginFailed, "获取用户 ID 失败") {
                    try user.requireID()
                }
                
                let token = Token(for: userId)
                
                return (user, userId, token)
            }.flatMap { (user, id, token) in
                // 删除原有的 token (若有)
                Token.query(on: db).filter(\.$user.$id == id).delete()
                    .withError(Errcase.userLoginFailed, "删除用户 token 时失败，用户: \(user)")
                    .map { (user, id, token) }
            }.flatMap { (user, id, token) in
                token.save(on: db)
                    .withError(Errcase.userLoginFailed, "用户 Token 写入数据库失败，用户: \(user)，token: \(token)")
                    .map { TokenDTO(from: token) }
            }
        }

        func authenticate(
            credential: String,
            tokenEncrypted: Data
        ) -> EventLoopRes<Crypto.Symm.Key, Errcase> {
            eventLoop.submitResult { () throws(Errcase.ErrType) in
                guard tokenEncrypted.count == 60 else {
                    throw .init(.userAuthenticateFailed, "用户口令长度不正确，预期为 60 bytes，而得到 \(tokenEncrypted.count) bytes", category: .parameter)
                }
            }.flatMap {
                Token.query(on: db)
                    .filter(\.$credential == credential)
                    .first()
                    .withError(Errcase.userAuthenticateFailed, "从数据库中获取用户凭据失败，凭据: \(credential)", category: .internel)
            }.flatMapThrowing { token throws(Errcase.ErrType) in
                guard let t = token else {
                    throw .init(.userAuthenticateFailed, "用户凭据不存在", category: .parameter)
                }
                return t
            }.flatMap { token in
                token.$user
                    .load(on: db)
                    .withError(Errcase.userAuthenticateFailed, "从数据中加载用户失败，凭据: \(credential)", category: .internel)
                    .map { token }
            }.flatMapThrowing { token throws(Errcase.ErrType) in
                // 检查是否有效
                guard token.valid == true else {
                    throw .init(.userAuthenticateFailed, "用户口令无效", category: .parameter)
                }
                
                // 检查是否已过期
                let expireDate = token.createdAt.addingTimeInterval(TimeInterval(token.expireAfter * 60))
                guard Date() < expireDate else {
                    throw .init(.userAuthenticateFailed, "用户凭据已过期", category: .parameter)
                }
                
                // 检查口令是否正确
                let keyData = try required(throws: Errcase.userAuthenticateFailed, "密钥字节解析失败", category: .parameter) {
                    try Base64String(token.token).dataRes.get()                                                             // 取得密钥的字节码
                }
                
                let key = Crypto.Symm.Key.new(data: keyData)                                                                // 转为 AES 密钥类型
                let authData: Data = try required(throws: Errcase.userAuthenticateFailed, "解密用户 Token 失败", category: .parameter) {
                    try Crypto.Symm.decrypt(tokenEncrypted, key: key).get()                                                 // 解密 tokenEncrypted
                }

                guard keyData == authData else {
                    throw .init(.userAuthenticateFailed, "用户口令不正确", category: .parameter)                               // key 是否一致
                }
                return key
            }
        }
        
        
    }
}
