import OPA
import ResourceDefine
import Foundation

/// `PrivilegeModule` 的简短命名空间别名。
///
/// 该别名可以让资源和权限 DTO 类型更易读：
///
/// ```swift
/// let dto = PM<ResourceList>.ResourceDTO<FileResource, DTO.Prepare>(data: file)
/// ```
public typealias PM = PrivilegeModule

/// 服务模块本地的资源权限模块。
///
/// `PrivilegeModule` 为一个业务模块保存资源记录和资源权限策略。当
/// `Arbitrator.judge` 收到 `privilegeIds` 时，中心 `PrivilegeSystem` 会让这些
/// 模块级 OPA 策略参与最终鉴权。
///
/// ```swift
/// enum ResourceList: String, ResourceTypeList {
///     case file
/// }
///
/// let module = try await PrivilegeModule<ResourceList>(
///     moduleId: UUID(),
///     eventLoop: eventLoop,
///     dbConfigure: moduleDatabase,
///     opaConfigure: .init(host: "localhost", port: 8181),
///     logger: .init(label: "PrivilegeModule"),
///     debuging: .init(tdeEncrypt: false)
/// )
/// ```
///
/// - Note: `ResourceList` 是该模块资源类型的封闭集合。每一个具体资源类型都需要
///   从这个集合中选择一个 case 作为自己的 `type`。
public final class PrivilegeModule<ResourceList: ResourceTypeList>: Sendable {
    @frozen
    /// 模块启动阶段使用的调试选项。
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
    
    /// 资源权限的创建、更新、删除和资源绑定控制器。
    public let privilege: PrivilegeController
    /// 类型化资源的创建、更新、删除和查询控制器。
    public let resource: ResourceController
    
    /// 执行数据库和 OPA 操作所使用的事件循环。
    public let eventLoop: EventLoop
    /// 稳定的模块标识，用于 OPA 策略路径和仲裁报告。
    public let moduleId: UUID
    let dbs: Databases
    package let db: PGDatabase
    let opa: OPA
    
    /// 创建并加载资源权限模块。
    ///
    /// 初始化器会准备模块数据库，并把持久化的资源权限策略同步到 OPA 中
    /// `moduleId` 对应的路径下。
    ///
    /// - Parameters:
    ///   - moduleId: 业务模块的稳定标识。
    ///   - eventLoop: 数据库和 OPA 操作使用的事件循环。
    ///   - dbConfigure: 模块数据库的 PostgreSQL 连接配置。
    ///   - opaConfigure: OPA 地址、端口和可选代理配置。
    ///   - logger: 模块控制器使用的根日志器。
    ///   - debuging: 可选测试/调试开关。生产环境一般不需要传入。
    ///
    /// - Throws: 当数据库迁移、数据库获取、OPA 初始化或策略同步失败时抛出
    ///   `PrivilegeModule.Errcase.ErrType`。
    public init(
        moduleId: UUID,
        eventLoop: EventLoop,
        dbConfigure: SQLPostgresConfiguration,
        opaConfigure: OPAConfiguration,
        logger: Logger,
        debuging: Debuging? = nil
    ) async throws(Errcase.ErrType) {
        self.eventLoop = eventLoop
        self.dbs = Databases(threadPool: .singleton, on: eventLoop)
        
        let initLogger = logger.derive(subId: "sysinit", metadata: ["moduleId": .stringConvertible(moduleId), "eventLoop": .id(eventLoop)])
        
        initLogger.info("正在初始化权限模块")
        
        do {
            initLogger.info("正在准备数据库")
            self.dbs.use(.postgres(configuration: dbConfigure), as: .psql)
            
            let migs = Migrations()
            
            for model in Self.DataModels {
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
        
        self.moduleId = moduleId
        self.opa = .init(argument: opaConfigure.conf(eventLoop: eventLoop, logger: initLogger.derive(subId: "opa")))
        self.db = db
        
        self.privilege = .init(db: db, opa: opa, moduleId: moduleId, eventLoop: eventLoop, logger: logger.derive(subId: "privilege"))
        self.resource = .init(db: db, eventLoop: eventLoop, logger: logger.derive(subId: "resource"))
        
        initLogger.info("权限控制器模块初始化完成")
        
        initLogger.info("正在进行 OPA 数据同步")
        try await opaInitialize(logger: initLogger.derive(subId: "opasync"))
        
        initLogger.info("权限模块初始化完成")
    }
}

/// OPA 服务连接配置。
///
/// 同一个鉴权图中的 `PrivilegeSystem` 和各个 `PrivilegeModule` 应连接到同一个 OPA。
public struct OPAConfiguration: Sendable {
    /// 连接 OPA 使用的 URL scheme。
    public let scheme: OPA.ConnectionArgument.Scheme
    /// OPA 主机名或 IP 地址。
    public let host: String
    /// OPA TCP 端口。
    public let port: Int
    /// 可选 HTTP 代理，常用于本地调试或 CI 路由。
    public let proxy: HTTPClient.Configuration.Proxy?
    
    /// 创建 OPA 连接配置。
    ///
    /// ```swift
    /// let opa = OPAConfiguration(host: "localhost", port: 8181)
    /// ```
    ///
    /// - Parameters:
    ///   - scheme: OPA 连接 scheme，默认使用 HTTP。
    ///   - host: OPA 主机，默认是 `localhost`。
    ///   - port: OPA 端口，默认是 `8181`。
    ///   - proxy: 可选 HTTP 代理。
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

extension PrivilegeModule: Query.System {
    /// 为某个模块 DTO 创建类型安全查询。
    ///
    /// ```swift
    /// let resources = try await module.query(AnyResource.self)
    ///     .page(with: 1, size: 20)
    /// ```
    ///
    /// - Parameter type: 要查询的 DTO 类型。大多数情况下 Swift 可以自动推断。
    /// - Returns: 针对该 DTO 配置好的 `Query.Builder`。
    public func query<T>(_ type: T.Type = T.self) -> Query.Builder<T> {
        .init(query: T.Model.query(on: db))
    }
}

extension PrivilegeModule: __QuerySystem {}

import Vapor

extension Request: Query.System {
    public func query<T>(_ model: T.Type) -> Query.Builder<T> where T : Query.Queriable {
        .init(query: T.Model.query(on: db))
    }
}
