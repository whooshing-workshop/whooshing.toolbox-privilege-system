import Foundation
import Cryptos
import Fluent
import PgSQL
import Vapor
import Policy
import DataConvertable
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    /// 权限服务层，提供权限相关的业务接口，负责账号注册、登录、Token 鉴权和密码修改等。
    ///
    /// `AccountController` 是处理 `User` 和 `Token` 数据结构生命周期的核心控制器。
    /// 它封装了底层数据库交互、双层盐化哈希密码验证、以及对称加密令牌机制，提供安全的无状态凭据验证。
    ///
    /// ### 账号注册
    /// 通过传入含有电子邮箱和一次性哈希密码（如 SHA256 等客户端完成的一次哈希）的 `PUser`，
    /// 可进行账号注册。控制器会自动在数据库中生成专有随机盐值并执行第二次哈希，从而落库：
    ///
    /// ```swift
    /// let userAuth = try await system.account.register(
    ///     email: "hello@example.com",
    ///     password: "hashedPasswordFromClient"
    /// )
    /// print("Registered user ID: \(userAuth.user.id)")
    /// ```
    ///
    /// ### 登录与鉴权
    /// 鉴权机制以令牌（Token）为核心，基于生成对称加密密钥（Crypto.Symm.Key）完成：
    ///
    /// ```swift
    /// // 登录并获取 Token 凭证
    /// let loginRes = try await system.account.login(by: userDto)
    /// let tokenStr = loginRes.token.tokenEncrypted // 包含验证信息的加密密文
    ///
    /// // 后续基于 tokenStr 发起请求鉴权
    /// let authKey = try await system.account.authenticate(token: receivedTokenDTO)
    /// ```
    public final class AccountController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        /// 操作记录日志器。
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
        
        /// 注册一个新账户，并将账户数据保存到数据库中。
        ///
        /// 注册接口会针对 `password` 字段（假设为已哈希的明文或直接明文）进行加盐（Salt）和双重哈希处理。
        ///
        /// - Parameter user: 用于注册的 `PUser` 准备对象，须包含有效的邮箱与基础密码数据。
        /// - Returns: 一个包裹在事件循环中的 `EventLoopRes` 结果，执行成功将返回注册完毕的 `QUser`。
        ///
        /// ```swift
        /// let dto = try PUser(email: "a@a.com", password: "pwd")
        /// let userQuery = try await system.account.register(for: dto).get()
        /// print("成功注册！", userQuery.id)
        /// ```
        public func register(
            for user: PUser
        ) -> EventLoopRes<QUser, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 账号注册 操作", metadata: ["user": .summaryData(user)])
            logger.debug("操作参数", metadata: ["user": .data(user)])
            
            return db.trans { db in
                db.eventLoop.submitResult { () throws(Errcase.ErrType) -> __SDBM.User in
                    try user.raw().get()
                }.flatMap { user in
                    user.save(on: db)
                        .withError(Errcase.userRegisterFailed, "将用户存入数据库时失败", category: .internal)
                        .map { user.id }
                }.flatMap { id in
                    __SDBM.User.find(id, on: db)
                        .withError(Errcase.userRegisterFailed, "重新加载用户失败", category: .internal)
                        .flatMapThrowing
                    { res throws(Errcase.ErrType) in
                        guard let user = res else {
                            throw .init(.userRegisterFailed, "用户未保存在数据库中，未知错误", category: .internal)
                        }
                        return try required(throws: Errcase.userRegisterFailed, "用户 DTO 生成失败", category: .internal) {
                            try required(throws: Errcase.userRegisterFailed, category: .internal) {
                                try QUser.make(from: user).get()
                            }
                        }
                    }
                }.map {
                    logger.info("账号注册 操作执行成功")
                    return $0
                }
            }.logIfFail(logger: logger, metadata: ["user": .data(user)])
        }
        
        /// 验证用户凭据并登录，系统将为其生成并返回令牌认证 DTO。
        ///
        /// 该方法使用用户的密码和邮箱数据，如果数据库验证一致，则该账户下所有以前活动的登录 Token 都将被删除，
        /// 重新为其生成一个新的凭证与加密对称密钥（Token）。
        ///
        /// - Parameter userData: 具有登录必要数据（如密码与邮箱）的用户对象。
        /// - Returns: 返回经过授权生成的鉴权 `QToken` 数据。
        ///
        /// ```swift
        /// let loginDto = try PUser(email: "test@domain.com", password: "pwd")
        /// let token = try await system.account.login(by: loginDto).get()
        /// print("登录完成，Token的加密体为: \(token.tokenEncrypted)")
        /// ```
        public func login(
            by userData: PUser
        ) -> EventLoopRes<QToken, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 账号登录 操作", metadata: ["user": .summaryData(userData)])
            logger.debug("操作参数", metadata: ["user": .data(userData)])
            
            return db.trans { db in
                __SDBM.User.query(on: db)
                    .filter(\.$email == userData.email)
                    .first()
                    .withError(Errcase.userLoginFailed, "用户不存在", category: .external)
                    .flatMapThrowing
                { (res) throws(Errcase.ErrType) -> (__SDBM.User, UUID, __SDBM.Token) in
                    guard let user = res else {
                        throw Errcase.userLoginFailed.d("用户不存在", category: .external)
                    }
                    
                    guard
                        try required(throws: Errcase.userLoginFailed, "密码验证失败", category: .internal, {
                            try user.verify(password: userData.hashedPassword)
                        })
                    else {
                        throw Errcase.userLoginFailed.d("用户密码不正确", category: .external)
                    }
                    
                    let userId = try required(throws: Errcase.userLoginFailed, "获取用户 ID 失败", category: .internal) {
                        try user.requireID()
                    }
                    
                    return (user, userId, PToken(for: userId).raw())
                }.flatMap { (user, id, token) in
                    // 删除原有的 token (若有)
                    __SDBM.Token.query(on: db).filter(\.$user.$id == id).delete()
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

        /// 对传入的 Token 发起鉴权并还原为加密用对称密钥。
        ///
        /// 接收请求上下文中提供的 Token 令牌。如果令牌格式合法、在有效期内且在数据库内验证一致，将还原为一个对称密钥。
        ///
        /// - Parameter token: 构建自外部的 `PToken`。
        /// - Returns: 若鉴权成功，将返回可供解密使用的 `Crypto.Symm.Key` 对称密钥。
        ///
        /// ```swift
        /// // 假装请求中的 header 里拿到 token 字符串
        /// let reqTokenString = req.headers["Authorization"].first!
        /// let tokenDto = PToken(tokenString: reqTokenString)
        /// let key = try await system.account.authenticate(token: tokenDto).get()
        /// ```
        public func authenticate(
            token: Token
        ) -> EventLoopRes<SendableSymmKey, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 Token 鉴权 操作", metadata: ["token": .summaryData(token)])
            logger.debug("操作参数", metadata: ["token": .data(token)])
            
            return db.trans { db in
                db.eventLoop.submitResult { () throws(Errcase.ErrType) in
                    guard token.tokenEncrypted.count == 60 else {
                        throw .init(.userAuthenticateFailed, "用户口令长度不正确，预期为 60 bytes", category: .external)
                    }
                }.flatMap {
                    __SDBM.Token.query(on: db)
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
                    return SendableSymmKey(key: key)
                }.map {
                    logger.info("Token 鉴权 操作执行成功")
                    return $0
                }
            }.logIfFail(logger: logger, metadata: ["token": .data(token)])
        }
        
        /// 为已知用户修改密码（以 Data 格式提供新哈希）。
        ///
        /// 用户的现有凭据 `userData` 中必须包含正确的旧密码哈希。
        /// 密码替换将触发重新生成盐值的操作。
        ///
        /// - Parameters:
        ///   - userData: `DTO.User` 实例，提供用户的电子邮箱及**当前正确的哈希密码**。
        ///   - hashedPassword: Data 格式的新的哈希密码流。
        /// - Returns: `QUser` 用户新的查询对象。
        public func changePassword(
            for userData: PUser,
            to hashedPassword: Data
        ) -> EventLoopRes<QUser, Errcase> {
            changePassword(for: userData, to: hashedPassword.base64EncodedString())
        }
        
        /// 为已知用户修改密码（以 String 格式提供新哈希）。
        ///
        /// 用户的现有凭据 `userData` 中必须包含正确的旧密码哈希。验证通过后，
        /// 系统将为新密码 `hashedPassword` 生成全新的随机盐值并覆盖记录。
        ///
        /// - Parameters:
        ///   - userData: `DTO.User` 实例，提供用户的电子邮箱及**当前正确的哈希密码**。
        ///   - hashedPassword: Base64 或其他格式编码的新字符串哈希密码。
        /// - Returns: `QUser` 密码已更改的查询对象。
        ///
        /// ```swift
        /// let newUserData = try await system.account.changePassword(
        ///     for: oldUserDto,
        ///     to: "brandNewHashedPwdStr"
        /// ).get()
        /// ```
        public func changePassword(
            for userData: PUser,
            to hashedPassword: String
        ) -> EventLoopRes<QUser, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 修改密码 操作", metadata: ["user": .summaryData(userData)])
            logger.debug("操作参数", metadata: ["token": .data(userData), "new_hashed_length": .stringConvertible(hashedPassword.count)])
            
            return db.trans { db in
                __SDBM.User.query(on: db)
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
                            try user.verify(password: userData.hashedPassword)
                        } == true
                    ) else {
                        throw Errcase.userPasswordChangeFailed.d("用户密码不正确", category: .external)
                    }
                    
                    (user.salt, user.hashedPassword) = try required(throws: Errcase.userPasswordChangeFailed, "双重加密密码时失败", category: .internal) {
                        try PUser.doubleEncode(hashedPassword: hashedPassword).get()
                    }
                    
                    return user
                }.flatMap { (user: __SDBM.User) -> EventLoopRes<__SDBM.User, Errcase> in
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
            }.logIfFail(logger: logger, metadata: ["token": .data(userData), "new_hashed_length": .stringConvertible(hashedPassword.count)])
        }
    }
}
