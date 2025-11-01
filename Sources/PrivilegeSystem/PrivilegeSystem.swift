import Cryptos
import PgSQL
import Foundation
import ErrorHandle
import FluentPostgresDriver

public struct PrivilegeSystem: Sendable {
    
    public typealias PGDatabase = Database & PostgresDatabase & SQLDatabase
    
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
    
    public let eventLoop: EventLoop
    let dbs: Databases
    let db: PGDatabase
    
    init(
        eventLoop: EventLoop,
        dbConfigure: SQLPostgresConfiguration,
        logger: Logger,
        debuging: Debuging? = nil
    ) async throws(BscError<Errcase>) {
        self.eventLoop = eventLoop
        self.dbs = Databases(threadPool: .singleton, on: eventLoop)
        
        do {
            self.dbs.use(.postgres(configuration: dbConfigure), as: .psql)
            
            let migs = Migrations()

            let models: [any TdeMIG.Type] = [
                User.MIG.self,
                Token.MIG.self,
                ACL.MIG.self,
                Role.MIG.self,
                UGroup.MIG.self,
                User.Info.MIG.self,
                UserRolePivot.MIG.self,
                UserGroupPivot.MIG.self,
                RoleGroupPivot.MIG.self,
                RoleUserInGroupPivot.MIG.self,
                User.Info.Extended<User.Info.Phone>.MIG.self,
                User.Info.Extended<User.Info.Address>.MIG.self,
                User.Info.Extended<User.Info.AlternateEmail>.MIG.self
            ]
            
            for model in models {
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
            throw Errcase.databaseInitFailed.d("数据库迁移失败").subErr(error)
        }
        
        guard let db = self.dbs.database(logger: logger, on: eventLoop) else {
            throw Errcase.databaseInitFailed.d("数据库获取失败")
        }
        
        guard let db = db as? PGDatabase else {
            throw Errcase.databaseInitFailed.d("数据库并非 PostgreSQL 数据库")
        }
        
        self.db = db
    }
}

public extension PrivilegeSystem {
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
    }
}
