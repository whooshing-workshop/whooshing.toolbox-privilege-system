import Foundation
import Cryptos
import Fluent
import PgSQL
import Vapor
import DataConvertable
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    /// 权限服务层，提供权限相关的业务接口
    public final class AccountController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.logger = logger
        }
        
        public func register(
            for user: DTO.User<DTO.Prepare>
        ) -> EventLoopRes<DTO.User<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 账号注册 操作", metadata: ["user": .summaryData(user)])
            logger.debug("操作参数", metadata: ["user": .data(user)])
            
            return db.trans { db in
                db.eventLoop.submitResult { () throws(Errcase.ErrType) -> User in
                    try user.raw().get()
                }.flatMap { user in
                    user.save(on: db)
                        .withError(Errcase.userRegisterFailed, "将用户存入数据库时失败", category: .internal)
                        .map { user.id }
                }.flatMap { id in
                    User.find(id, on: db)
                        .withError(Errcase.userRegisterFailed, "重新加载用户失败", category: .internal)
                        .flatMapThrowing
                    { res throws(Errcase.ErrType) in
                        guard let user = res else {
                            throw .init(.userRegisterFailed, "用户未保存在数据库中，未知错误", category: .internal)
                        }
                        return try required(throws: Errcase.userRegisterFailed, "用户 DTO 生成失败", category: .internal) {
                            try required(throws: Errcase.userRegisterFailed, category: .internal) {
                                try DTO.User.make(from: user).get()
                            }
                        }
                    }
                }.map {
                    logger.info("账号注册 操作执行成功")
                    return $0
                }
            }.logIfFail(logger: logger, metadata: ["user": .data(user)])
        }
        
        public func login(
            by userData: DTO.User<DTO.Prepare>
        ) -> EventLoopRes<DTO.Token<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 账号登录 操作", metadata: ["user": .summaryData(userData)])
            logger.debug("操作参数", metadata: ["user": .data(userData)])
            
            return db.trans { db in
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
                        try required(throws: Errcase.userLoginFailed, "密码验证失败", category: .internal, {
                            try user.verify(password: userData.hashedPasswd)
                        })
                    else {
                        throw Errcase.userLoginFailed.d("用户密码不正确", category: .external)
                    }
                    
                    let userId = try required(throws: Errcase.userLoginFailed, "获取用户 ID 失败", category: .internal) {
                        try user.requireID()
                    }
                    
                    let token = try required(throws: Errcase.userLoginFailed, "创建 Token 时失败", category: .internal) {
                        try DTO.Token<DTO.Prepare>(for: userId).raw()
                    }
                    
                    return (user, userId, token)
                }.flatMap { (user, id, token) in
                    // 删除原有的 token (若有)
                    Token.query(on: db).filter(\.$user.$id == id).delete()
                        .withError(Errcase.userLoginFailed, "删除用户 token 时失败，用户: \(user)")
                        .map { (user, id, token) }
                }.flatMap { (user, id, token) in
                    token.save(on: db)
                        .withError(Errcase.userLoginFailed, "用户 Token 写入数据库失败，用户: \(user)，token: \(token)")
                        .flatMapThrowing
                    { () throws(Errcase.ErrType) in
                        try required(throws: Errcase.userLoginFailed, category: .internal) {
                            try .make(from: token).get()
                        }
                    }
                }.map {
                    logger.info("账号登录 操作执行成功", metadata: ["user": .string(userData.email)])
                    return $0
                }
            }.logIfFail(logger: logger, metadata: ["user": .data(userData)])
        }

        public func authenticate(
            token: DTO.Token<DTO.Prepare>
        ) -> EventLoopRes<Crypto.Symm.Key, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 Token 鉴权 操作", metadata: ["token": .summaryData(token)])
            logger.debug("操作参数", metadata: ["token": .data(token)])
            
            return db.trans { db in
                db.eventLoop.submitResult { () throws(Errcase.ErrType) in
                    guard token.tokenEncrypted.count == 60 else {
                        throw .init(.userAuthenticateFailed, "用户口令长度不正确，预期为 60 bytes", category: .external)
                    }
                }.flatMap {
                    Token.query(on: db)
                        .filter(\.$credential == token.credential)
                        .first()
                        .withError(Errcase.userAuthenticateFailed, "从数据库中获取用户凭据失败", category: .internal)
                }.flatMapThrowing { token throws(Errcase.ErrType) in
                    guard let t = token else {
                        throw .init(.userAuthenticateFailed, "用户凭据不存在", category: .external)
                    }
                    return t
                }.flatMap { token in
                    token.$user
                        .load(on: db)
                        .withError(Errcase.userAuthenticateFailed, "从数据中加载用户失败", category: .internal)
                        .map { @Sendable in token }
                }.flatMapThrowing { tokenResult throws(Errcase.ErrType) in
                    // 检查是否有效
                    guard tokenResult.valid == true else {
                        throw .init(.userAuthenticateFailed, "用户口令无效", category: .external)
                    }
                    
                    // 检查是否已过期
                    let expireDate = tokenResult.createdAt.addingTimeInterval(TimeInterval(tokenResult.expireAfter * 60))
                    guard Date() < expireDate else {
                        throw .init(.userAuthenticateFailed, "用户凭据已过期", category: .external)
                    }
                    
                    // 检查口令是否正确
                    let keyData = try required(throws: Errcase.userAuthenticateFailed, "密钥字节解析失败", category: .external) {
                        try Base64String(tokenResult.token).dataRes.get()                           // 取得密钥的字节码
                    }
                    
                    let key = Crypto.Symm.Key.new(data: keyData)                                    // 转为 AES 密钥类型
                    let authData: Data = try required(throws: Errcase.userAuthenticateFailed, "解密用户 Token 失败", category: .external) {
                        try Crypto.Symm.decrypt(token.tokenEncrypted, key: key).get()               // 解密 tokenEncrypted
                    }

                    guard keyData == authData else {
                        throw .init(.userAuthenticateFailed, "用户口令不正确", category: .external)    // key 是否一致
                    }
                    return key
                }.map {
                    logger.info("Token 鉴权 操作执行成功")
                    return $0
                }
            }.logIfFail(logger: logger, metadata: ["token": .data(token)])
        }
        
        public func changePassword(
            for userData: DTO.User<DTO.Prepare>,
            to hashedPasswd: Data
        ) -> EventLoopRes<DTO.User<DTO.Queried>, Errcase> {
            changePassword(for: userData, to: hashedPasswd.base64EncodedString())
        }
        
        public func changePassword(
            for userData: DTO.User<DTO.Prepare>,
            to hashedPasswd: String
        ) -> EventLoopRes<DTO.User<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 修改密码 操作", metadata: ["user": .summaryData(userData)])
            logger.debug("操作参数", metadata: ["token": .data(userData), "new_hashed_length": .stringConvertible(hashedPasswd.count)])
            
            return db.trans { db in
                User.query(on: db)
                    .filter(\.$email == userData.email)
                    .first()
                    .withError(Errcase.userPasswordChangeFailed, "用户不存在", category: .external)
                    .flatMapThrowing
                { (res) throws(Errcase.ErrType) in
                    guard let user = res else {
                        throw Errcase.userPasswordChangeFailed.d("用户不存在", category: .external)
                    }
                    
                    guard (
                        try required(throws: Errcase.userPasswordChangeFailed, "用户密码认证失败", category: .internal) {
                            try user.verify(password: userData.hashedPasswd)
                        } == true
                    ) else {
                        throw Errcase.userPasswordChangeFailed.d("用户密码不正确", category: .external)
                    }
                    
                    (user.salt, user.hashedPasswd) = try required(throws: Errcase.userPasswordChangeFailed, "双重加密密码时失败", category: .internal) {
                        try DTO.User<DTO.Prepare>.doubleEncode(hashedPasswd: hashedPasswd).get()
                    }
                    
                    return user
                }.flatMap { (user: User) -> EventLoopRes<User, Errcase> in
                    return user
                        .update(on: db)
                        .withError(Errcase.userPasswordChangeFailed, "更新用户密码时失败", category: .internal)
                        .map { user }
                }.flatMapThrowing { user throws(Errcase.ErrType) in
                    try required(throws: Errcase.userPasswordChangeFailed, category: .internal) {
                        try .make(from: user).get()
                    }
                }.map {
                    logger.info("修改密码 操作执行成功")
                    return $0
                }
            }.logIfFail(logger: logger, metadata: ["token": .data(userData), "new_hashed_length": .stringConvertible(hashedPasswd.count)])
        }
    }
}
