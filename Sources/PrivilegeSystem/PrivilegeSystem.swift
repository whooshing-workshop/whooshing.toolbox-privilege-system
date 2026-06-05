import OPA
import PgSQL
import ErrorHandle
import FluentPostgresDriver
import PrivilegeModule
import Query
import Logging
import LoggingAdvanced

public final class PrivilegeSystem: Sendable {
    @frozen
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
    
    public let account: AccountController
    public let userInfo: UserInfoController
    public let infoSlice: InfoSliceController
    public let group: GroupController
    
    public let role: RoleController
    public let domain: DomainController
    public let policy: PolicyController
    
    public let arbitrator: Arbitrator
    
    public let eventLoop: EventLoop
    let dbs: Databases
    let db: PGDatabase
    let opa: OPA
    
    public init(
        eventLoop: EventLoop,
        dbConfigure: SQLPostgresConfiguration,
        opaConfigure: OPAConfiguration,
        logger: Logger,
        debuging: Debuging? = nil
    ) async throws(BscError<Errcase>) {
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
                logger: initLogger,
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
        
        guard let db = self.dbs.database(logger: initLogger, on: eventLoop) else {
            throw initLogger.errThrow(Errcase.databaseInitFailed.d("数据库获取失败", category: .internal))
        }
        
        guard let db = db as? PGDatabase else {
            throw initLogger.errThrow(Errcase.databaseInitFailed.d("数据库并非 PostgreSQL 数据库", category: .internal))
        }
        
        self.opa = .init(argument: opaConfigure.conf(eventLoop: eventLoop, logger: initLogger.derive(subId: "opa")))
        self.db = db
        
        self.account = .init(db: db, eventLoop: eventLoop, logger: logger.derive(subId: "account"))
        self.infoSlice = .init(db: db, eventLoop: eventLoop, logger: logger.derive(subId: "infoslice"))
        self.userInfo = .init(db: db, eventLoop: eventLoop, infoSliceController: self.infoSlice, logger: logger.derive(subId: "userinfo"))
        self.group = .init(db: db, eventLoop: eventLoop, logger: logger.derive(subId: "group"))
        self.policy = .init(db: db, eventLoop: eventLoop, opa: opa, logger: logger.derive(subId: "policy"))
        self.role = .init(db: db, eventLoop: eventLoop, groupController: self.group, policyController: self.policy, logger: logger.derive(subId: "role"))
        self.domain = .init(db: db, eventLoop: eventLoop, policyController: self.policy, logger: logger.derive(subId: "domain"))
        self.arbitrator = .init(db: db, eventLoop: eventLoop, opa: opa, roleController: self.role, logger: logger.derive(subId: "arbitrator"))
        
        initLogger.info("权限控制器模块初始化完成")
        
        initLogger.info("正在加载系统")
        try await systemInitialize(dbConfigure: dbConfigure, logger: initLogger.derive(subId: "sysloader"))
        initLogger.info("正在进行 OPA 数据同步")
        try await opaInitialize(logger: initLogger.derive(subId: "opasync"))
        
        initLogger.info("权限系统初始化完成")
    }
}

public extension PrivilegeSystem {
    func query<T>(_ type: T.Type = T.self) -> Query.Builder<T> {
        .init(query: T.Model.query(on: db))
    }
}
