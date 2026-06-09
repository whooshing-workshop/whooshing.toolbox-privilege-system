import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    /// 域权限控制器，提供域的创建、更新、删除及关系指派接口。
    ///
    /// 域（Domain）是权限系统中的一个环境隔离层。它可以被指派给用户或群组，
    /// 代表该用户或群组在一个特定维度（如：“公司A”，“项目B”）下拥有一组策略约束。
    ///
    /// - `create(domains:)` / `create(relations:)`：单独创建域或附带 OPA 策略一同创建。
    /// - `assign` / `unassign`：将域指派给用户或群组，或从中撤销。
    ///
    /// 域本身不支持层级嵌套（不像群组），但可以附加域策略，供 `Arbitrator` 进行仲裁时作为附加环境约束。
    public final class DomainController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        let policyController: PolicyController
        
        /// 操作记录日志器。
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            policyController: PolicyController,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.policyController = policyController
            self.logger = logger
        }
        
        /// 批量创建域并附带 OPA 策略。
        ///
        /// 允许在声明域的同时将一条或多条 `DTO.Policy` 关联到该域。底层通过事务保证原子性。
        ///
        /// - Parameter content: `MTORelationBuilder` 闭包，用于构建域与策略间的多对一关系。
        /// - Returns: `EventLoopRes<Void, Errcase>`
        ///
        /// ```swift
        /// try await system.domain.create {
        ///     [domainPolicyDTO] => domainDTO
        /// }.get()
        /// ```
        public func create(
            @MTORelationBuilder<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            self.create(relations: content())
        }
        
        /// 批量创建域并附带 OPA 策略，返回存入的策略查询结构。
        ///
        /// - Parameter content: `MTORelationBuilder` 闭包，用于构建域与策略间的多对一关系。
        /// - Returns: 一个字典，Key为域的 ID，Value 为该域关联的策略查询对象 `DTO.Policy<Domain, DTO.Queried>`。
        public func createWithReturning(
            @MTORelationBuilder<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
        ) -> EventLoopRes<[UUID: [DTO.Policy<Domain, DTO.Queried>]], Errcase> {
            self.createWithReturning(relations: content())
        }
        
        /// 批量创建裸域（无策略附带）。
        ///
        /// - Parameter domains: 一组准备落库的域对象。
        /// - Returns: 成功后返回携带数据库 UUID 的查询对象 `DTO.Domain<DTO.Queried>` 数组。
        ///
        /// ```swift
        /// let domains = try await system.domain.create(
        ///     domains: [.init(name: "DomainA", description: "This is A")]
        /// ).get()
        /// ```
        public func create(
            domains: [DTO.Domain<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Domain<DTO.Queried>], Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建域权限 操作", metadata: ["domains": .summaryData(domains)])
            logger.debug("操作参数", metadata: ["domains": .data(domains)])
            return __create(on: db, domains: domains)
                .map { 
                logger.info("创建域权限 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("创建域权限 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
                .logIfFail(logger: logger)
        }
        
        /// 根据 ID 批量删除域。
        ///
        /// - Parameters:
        ///   - domainIds: 欲删除域的 UUID 数组。
        ///   - allSatisfy: 是否必须满足全部删除（若传入的 ID 存在未删除的部分则报错回滚）。
        /// - Returns: `EventLoopRes<Void, Errcase>`
        public func delete(
            domainIds: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除域权限 操作", metadata: ["domainIds": .summaryData(domainIds)])
            logger.debug("操作参数", metadata: ["domainIds": .data(domainIds)])
            return __delete(
                on: db,
                Domain.self,
                ids: domainIds,
                allSatisfy: allSatisfy,
                label: "域权限",
                errThrowing: .domainDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ domainIds) }
            )
            .map { logger.info("删除域权限 操作成功") }
            .logIfFail(logger: logger)
        }
        
        /// 更新指定域的元信息。
        ///
        /// - Parameter updater: 更新器对象 `DTO.Domain<DTO.Prepare>.Updater`。
        /// - Returns: 更新完毕的域对象 `DTO.Domain<DTO.Queried>`。
        public func update(
            with updater: DTO.Domain<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Domain<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新域权限 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新域权限 详细请求数据", metadata: ["data": .data(updater)])
            return __update(
                on: db,
                updater: updater,
                label: "域权限",
                errThrowing: .domainUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.domainId) },
                dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0) }
            )
            .map { 
                logger.info("更新域权限 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("更新域权限 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
    }
}

public extension PrivilegeSystem.DomainController {
    func create(
        relations: [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建域权限（含策略） 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return db.trans { db in
            self.__create(on: db, domains: relations.map { $0.right }).flatMap { _ in
                self.policyController.__create(
                    on: db,
                    to: Domain.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
        .map { logger.info("创建域权限（含策略） 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func createWithReturning(
        relations: [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) -> EventLoopRes<[UUID: [DTO.Policy<Domain, DTO.Queried>]], PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建域权限（含策略返回） 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return db.trans { db in
            self.__create(on: db, domains: relations.map { $0.right }).flatMap { _ in
                self.policyController.__createWithReturning(
                    on: db,
                    to: Domain.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
        .map { 
                logger.info("创建域权限（含策略返回） 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("创建域权限（含策略返回） 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
        .logIfFail(logger: logger)
    }
}
        
public extension PrivilegeSystem.DomainController {
    // MARK: - 域权限指派
    
    /// 将一个或多个域指派给一个或多个用户。
    ///
    /// 此操作支持闭包式的多对多 DSL 构建方式：
    /// ```swift
    /// try await system.domain.assign {
    ///     [domainA, domainB] => [user1, user2]
    /// }.get()
    /// ```
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func assign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(relations: content())
    }
    
    /// 将一个或多个域指派给一个或多个群组。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func assign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(relations: content())
    }
    
    // MARK: - 域权限撤销
    
    /// 撤销特定用户对某些域的指派关系。
    ///
    /// - Parameter content: 欲撤销的 `MTMRelationBuilder` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func unassign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(relations: content())
    }
    
    /// 撤销特定群组对某些域的指派关系。
    ///
    /// - Parameter content: 欲撤销的 `MTMRelationBuilder` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func unassign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(relations: content())
    }
}

public extension PrivilegeSystem.DomainController {
    // MARK: - 域权限指派
    
    func assign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限指派用户 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限指派用户关系详情", metadata: ["detail": .data(relations)])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "域权限与用户",
            errThrowing: .domainAssignUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("域权限指派用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func assign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限指派用户组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限指派用户组关系详情", metadata: ["detail": .data(relations)])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "域权限与用户组",
            errThrowing: .domainAssignGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("域权限指派用户组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 域权限撤销
    
    func unassign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限撤销用户 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限撤销用户关系详情", metadata: ["detail": .data(relations)])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "域权限与用户",
            errThrowing: .domainUnassignUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("域权限撤销用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func unassign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限撤销用户组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限撤销用户组关系详情", metadata: ["detail": .data(relations)])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "域权限与用户组",
            errThrowing: .domainUnassignGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("域权限撤销用户组 操作成功") }
        .logIfFail(logger: logger)
    }
}

extension PrivilegeSystem.DomainController {
    func __create(
        on db: PGDatabase,
        domains: [DTO.Domain<DTO.Prepare>]
    ) -> EventLoopRes<[DTO.Domain<DTO.Queried>], PrivilegeSystem.Errcase> {
        __create(
            on: db,
            dtos: domains,
            label: "域权限",
            errThrowing: .domainCreateFailed,
            modelBuilder: { $0.raw() },
            dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0.fill()) }
        )
    }
}
