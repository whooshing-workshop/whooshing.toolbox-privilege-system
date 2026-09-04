import PrivilegeModule

/// Whooshing 权限系统的中心入口。
///
/// `PrivilegeSystem` 负责初始化权限侧数据库、同步 OPA 策略，并暴露账号、群组、
/// 角色、域、策略和权限仲裁等控制器。服务端通常在应用启动时创建一个实例，
/// 然后在请求处理流程中复用其中的控制器。
///
/// ```swift
/// let system = try await PrivilegeSystem(
///     eventLoop: eventLoop,
///     dbConfigure: systemDatabase,
///     opaConfigure: .init(host: "localhost", port: 8181),
///     logger: .init(label: "PrivilegeSystem"),
///     debuging: .init(tdeEncrypt: false)
/// )
///
/// let user = try await system.query(QUser.self)
///     .filter(\.email == "user1@example.com")
///     .first()
/// ```
///
/// - Important: 初始化会执行数据库迁移，并将已保存的角色/域策略上传到 OPA。
///   通常应在进程或应用生命周期内只创建一次，而不是在每个请求中创建。
public final class PrivilegeSystem: Sendable {
    @frozen
    /// 系统启动阶段使用的调试选项。
    ///
    /// 生产环境通常应保持所有安全特性开启。测试环境中的 PostgreSQL 如果没有安装
    /// TDE 扩展，可以传入 `Debuging(tdeEncrypt: false)`。
    public struct Debuging: Sendable {
        /// 是否启用 PostgreSQL tde 加密功能
        ///
        /// 一般的数据库中并未配置 tde 加密扩展，这通常需要修改数据库服务器配置文件
        /// 因此，为了方便测试，可暂时取消其加密机制
        public let tdeEncrypt: Bool
        
        /// 初始化该调试参数
        public init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
    
    /// 账号注册、登录、Token 鉴权和密码修改控制器。
    public let account: AccountController
    /// 用户主资料控制器。
    public let userInfo: UserInfoController
    /// 用户扩展资料切片控制器，例如地址、备用邮箱和手机号。
    public let infoSlice: InfoSliceController
    /// 群组成员关系和嵌套群组层级控制器。
    public let group: GroupController
    
    /// 角色创建、角色指派和角色可用性查询控制器。
    public let role: RoleController
    /// 域创建，以及域对用户或群组的指派控制器。
    public let domain: DomainController
    /// 角色/域策略创建、替换和删除控制器。
    public let policy: PolicyController
    
    /// 权限仲裁器，用于合并角色、域和资源权限策略并给出最终判定。
    public let arbitrator: Arbitrator
    
    /// 执行数据库和 OPA 操作所使用的事件循环。
    public let eventLoop: EventLoop
    public let logger: Logger
    
    public let origin: Transactor
    
    /// 保留的角色名称，无法创建该名称的角色，除非使用所提供的特殊方式
    public let reservedRoleName: [String]
    
    let dbs: Databases
    package let pgDB: PGDatabase
    let opa: OPA
    
    /// 创建并加载权限系统实例。
    ///
    /// 初始化器会准备 PostgreSQL 迁移、构建所有控制器，并将持久化的系统策略同步到 OPA。
    ///
    /// ```swift
    /// let system = try await PrivilegeSystem(
    ///     eventLoop: eventLoop,
    ///     dbConfigure: .init(
    ///         hostname: "localhost",
    ///         port: 5432,
    ///         username: "woo",
    ///         password: "testing",
    ///         database: "privilege_system",
    ///         tls: .disable
    ///     ),
    ///     opaConfigure: .init(host: "localhost", port: 8181),
    ///     logger: .init(label: "PrivilegeSystem"),
    ///     debuging: .init(tdeEncrypt: false)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - eventLoop: PostgreSQL、OPA 和各控制器使用的事件循环。
    ///   - dbConfigure: 权限系统数据库的 PostgreSQL 连接配置。
    ///   - opaConfigure: OPA 地址、端口和可选代理配置。
    ///   - logger: 根日志器，各控制器会从它派生子日志器。
    ///   - debuging: 可选测试/调试开关。生产环境一般不需要传入。
    ///
    /// - Throws: 当数据库迁移、数据库获取、OPA 初始化或策略同步失败时抛出
    ///   `PrivilegeSystem.Errcase.ErrType`。
    public init(
        eventLoop: EventLoop,
        dbConfigure: SQLPostgresConfiguration,
        opaConfigure: OPAConfiguration,
        reservedRoleName: [String],
        logger: Logger,
        debuging: Debuging? = nil
    ) async throws(Errcase.ErrType) {
        self.eventLoop = eventLoop
        self.dbs = Databases(threadPool: .singleton, on: eventLoop)
        
        let initLogger = logger.derive(subId: "sysinit", metadata: ["eventLoop": .id(eventLoop)])
        
        initLogger.info("正在初始化权限系统")
        
        do {
            initLogger.info("正在准备数据库")
            self.dbs.use(.postgres(configuration: dbConfigure), as: .psql)
            
            let migs = Migrations()
            
            for model in DataModels {
                migs.add(model.init(tdeEncrypt: debuging?.tdeEncrypt ?? true))
            }
            
            let mig = Migrator(
                databases: self.dbs,
                migrations: migs,
                logger: logger.derive(subId: "db"),
                on: eventLoop,
                migrationLogLevel: initLogger.logLevel
            )
            
            try await mig.setupIfNeeded().get()
            try await mig.prepareBatch().get()
            
            initLogger.info("数据库准备成功")
        } catch {
            await self.dbs.shutdownAsync()
            try? await eventLoop.shutdownGracefully()
            
            throw initLogger.errThrow(Errcase.databaseInitFailed.d("数据库迁移失败", category: .internal).subErr(error))
        }
        
        guard let db = self.dbs.database(logger: logger.derive(subId: "db"), on: eventLoop) else {
            throw initLogger.errThrow(Errcase.databaseInitFailed.d("数据库获取失败", category: .internal))
        }
        
        guard let db = db as? PGDatabase else {
            throw initLogger.errThrow(Errcase.databaseInitFailed.d("数据库并非 PostgreSQL 数据库", category: .internal))
        }
        
        self.opa = .init(argument: opaConfigure.conf(eventLoop: eventLoop, logger: initLogger.derive(subId: "opa")))
        self.pgDB = db
        
        self.infoSlice = .init(db: db, eventLoop: eventLoop, logger: logger.derive(subId: "infoslice"))
        self.userInfo = .init(db: db, eventLoop: eventLoop, infoSliceController: self.infoSlice, logger: logger.derive(subId: "userinfo"))
        self.group = .init(db: db, eventLoop: eventLoop, logger: logger.derive(subId: "group"))
        self.policy = .init(db: db, eventLoop: eventLoop, opa: opa, logger: logger.derive(subId: "policy"))
        self.role = .init(db: db, eventLoop: eventLoop, policyController: self.policy, reservedRoleName: reservedRoleName, logger: logger.derive(subId: "role"))
        self.account = .init(db: db, eventLoop: eventLoop, roleController: self.role, logger: logger.derive(subId: "account"))
        self.domain = .init(db: db, eventLoop: eventLoop, policyController: self.policy, logger: logger.derive(subId: "domain"))
        self.arbitrator = .init(db: db, eventLoop: eventLoop, opa: opa, roleController: self.role, logger: logger.derive(subId: "arbitrator"))
        self.reservedRoleName = reservedRoleName
        self.logger = logger
        self.origin = .init(db: db)
        
        initLogger.info("权限控制器模块初始化完成")
        
        initLogger.info("正在加载系统")
        try await systemInitialize(dbConfigure: dbConfigure, logger: initLogger.derive(subId: "sysloader"))
        initLogger.info("正在进行 OPA 数据同步")
        try await opaInitialize(logger: initLogger.derive(subId: "opasync"))
        
        initLogger.info("权限系统初始化完成")
    }
}
