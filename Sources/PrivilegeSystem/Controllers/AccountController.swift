import Foundation
import Cryptos
import Fluent
import Vapor
import DataConvertable
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    /// 权限服务层，提供权限相关的业务接口
    public struct AccountController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
        
        func register(
            for user: DTO.User<DTO.Prepare>
        ) -> EventLoopRes<DTO.User<DTO.Queried>, Errcase> {
            eventLoop.submitResult { () throws(Errcase.ErrType) -> User in
                try user.raw().get()
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
                    return try required(throws: Errcase.userRegisterFailed, "用户 DTO 生成失败", category: .internel) {
                        try DTO.User.make(from: user).get()
                    }
                }
            }
        }
        
        func login(
            by userData: DTO.User<DTO.Prepare>
        ) -> EventLoopRes<DTO.Token<DTO.Queried>, Errcase> {
            User.query(on: db)
                .filter(\.$email == userData.email)
                .first()
                .withError(Errcase.userLoginFailed, "用户不存在", category: .external)
                .flatMapThrowing
            { (res) throws(Errcase.ErrType) -> (User, UUID, Token) in
                guard let user = res else {
                    throw Errcase.userLoginFailed.d("用户不存在", category: .external)
                }
                
                guard
                    try required(throws: Errcase.userLoginFailed, "密码验证失败", category: .internel, {
                        try user.verify(password: userData.hashedPasswd)
                    })
                else {
                    throw Errcase.userLoginFailed.d("用户密码不正确", category: .external)
                }
                
                let userId = try required(throws: Errcase.userLoginFailed, "获取用户 ID 失败") {
                    try user.requireID()
                }
                
                let token = DTO.Token<DTO.Prepare>(for: userId).raw()
                
                return (user, userId, token)
            }.flatMap { (user, id, token) in
                // 删除原有的 token (若有)
                Token.query(on: db).filter(\.$user.$id == id).delete()
                    .withError(Errcase.userLoginFailed, "删除用户 token 时失败，用户: \(user)")
                    .map { (user, id, token) }
            }.flatMap { (user, id, token) in
                token.save(on: db)
                    .withError(Errcase.userLoginFailed, "用户 Token 写入数据库失败，用户: \(user)，token: \(token)")
                    .flatMapResult { DTO.Token.make(from: token) }
            }
        }

        func authenticate(
            credential: String,
            tokenEncrypted: Data
        ) -> EventLoopRes<Crypto.Symm.Key, Errcase> {
            eventLoop.submitResult { () throws(Errcase.ErrType) in
                guard tokenEncrypted.count == 60 else {
                    throw .init(.userAuthenticateFailed, "用户口令长度不正确，预期为 60 bytes，而得到 \(tokenEncrypted.count) bytes", category: .external)
                }
            }.flatMap {
                Token.query(on: db)
                    .filter(\.$credential == credential)
                    .first()
                    .withError(Errcase.userAuthenticateFailed, "从数据库中获取用户凭据失败，凭据: \(credential)", category: .internel)
            }.flatMapThrowing { token throws(Errcase.ErrType) in
                guard let t = token else {
                    throw .init(.userAuthenticateFailed, "用户凭据不存在", category: .external)
                }
                return t
            }.flatMap { token in
                token.$user
                    .load(on: db)
                    .withError(Errcase.userAuthenticateFailed, "从数据中加载用户失败，凭据: \(credential)", category: .internel)
                    .map { @Sendable in token }
            }.flatMapThrowing { token throws(Errcase.ErrType) in
                // 检查是否有效
                guard token.valid == true else {
                    throw .init(.userAuthenticateFailed, "用户口令无效", category: .external)
                }
                
                // 检查是否已过期
                let expireDate = token.createdAt.addingTimeInterval(TimeInterval(token.expireAfter * 60))
                guard Date() < expireDate else {
                    throw .init(.userAuthenticateFailed, "用户凭据已过期", category: .external)
                }
                
                // 检查口令是否正确
                let keyData = try required(throws: Errcase.userAuthenticateFailed, "密钥字节解析失败", category: .external) {
                    try Base64String(token.token).dataRes.get()                                                             // 取得密钥的字节码
                }
                
                let key = Crypto.Symm.Key.new(data: keyData)                                                                // 转为 AES 密钥类型
                let authData: Data = try required(throws: Errcase.userAuthenticateFailed, "解密用户 Token 失败", category: .external) {
                    try Crypto.Symm.decrypt(tokenEncrypted, key: key).get()                                                 // 解密 tokenEncrypted
                }

                guard keyData == authData else {
                    throw .init(.userAuthenticateFailed, "用户口令不正确", category: .external)                               // key 是否一致
                }
                return key
            }
        }
    }
}
