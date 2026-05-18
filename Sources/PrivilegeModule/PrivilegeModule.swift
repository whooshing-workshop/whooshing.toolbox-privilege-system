import OPA
import PgSQL
import ErrorHandle
import FluentPostgresDriver
import ResourceMacros
import AsyncHTTPClient
import Query

public protocol ResourceTypeList: Sendable, Codable, CaseIterable, RawRepresentable, Hashable
where Self.RawValue == String {}

public typealias PM = PrivilegeModule

public struct PrivilegeModule<ResourceList: ResourceTypeList>: Sendable {
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
    
    public let privilege: PrivilegeController
    public let resource: ResourceController
    
    public let eventLoop: EventLoop
    public let moduleId: UUID
    let dbs: Databases
    let db: PGDatabase
    let opa: OPA
    
    public init(
        moduleId: UUID,
        eventLoop: EventLoop,
        dbConfigure: SQLPostgresConfiguration,
        opaConfigure: OPAConfiguration,
        logger: Logger,
        debuging: Debuging? = nil
    ) async throws(BscError<Errcase>) {
        self.eventLoop = eventLoop
        self.dbs = Databases(threadPool: .singleton, on: eventLoop)
        
        do {
            self.dbs.use(.postgres(configuration: dbConfigure), as: .psql)
            
            let migs = Migrations()
            
            for model in Self.DataModels {
                migs.add(model.init(tdeEncrypt: debuging?.tdeEncrypt ?? true))
            }
            
            let mig = Migrator(
                databases: self.dbs,
                migrations: migs,
                logger: logger,
                on: eventLoop,
                migrationLogLevel: logger.logLevel
            )
            try await mig.setupIfNeeded().get()
            try await mig.prepareBatch().get()
        } catch {
            await self.dbs.shutdownAsync()
            try? await eventLoop.shutdownGracefully()
            throw Errcase.databaseInitFailed.d("数据库迁移失败", category: .internal).subErr(error)
        }
        
        guard let db = self.dbs.database(logger: logger, on: eventLoop) else {
            throw Errcase.databaseInitFailed.d("数据库获取失败", category: .internal)
        }
        
        guard let db = db as? PGDatabase else {
            throw Errcase.databaseInitFailed.d("数据库并非 PostgreSQL 数据库", category: .internal)
        }
        
        self.moduleId = moduleId
        self.opa = .init(argument: opaConfigure.conf(eventLoop: eventLoop, logger: logger.derive(subId: "opa")))
        self.db = db
        
        self.privilege = .init(db: db, opa: opa, moduleId: moduleId, eventLoop: eventLoop)
        self.resource = .init(db: db, eventLoop: eventLoop)
        
        try await required(throws: Errcase.opaInitFailed) {
            try await opaInitialize()
        }
    }
}

public struct OPAConfiguration: Sendable {
    public let scheme: OPA.ConnectionArgument.Scheme
    public let host: String
    public let port: Int
    public let proxy: HTTPClient.Configuration.Proxy?
    
    public init(
        scheme: OPA.ConnectionArgument.Scheme = .http,
        host: String = "localhost",
        port: Int = 8181,
        proxy: HTTPClient.Configuration.Proxy? = nil
    ) {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.proxy = proxy
    }
    
    package func conf(eventLoop: EventLoop, logger: Logger) -> OPA.ConnectionArgument {
        .init(
            eventLoop: eventLoop,
            scheme: scheme,
            host: host,
            port: port,
            logger: logger,
            proxy: proxy
        )
    }
}

public extension PrivilegeModule {
    func query<T>(_ type: T.Type = T.self) -> Query.Builder<T> {
        .init(query: T.Model.query(on: db))
    }
}
