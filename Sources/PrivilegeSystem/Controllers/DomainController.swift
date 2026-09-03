import Query
import Foundation
import PrivilegeModule

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
            on transactor: Transactor? = nil,
            @MTORelationBuilder<PPolicy<Domain>, PDomain>
            _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>
        ) -> EventLoopRes<Void, Errcase> {
            self.create(relations: content(), on: transactor)
        }
        
        /// 批量创建域并附带 OPA 策略，返回存入的策略查询结构。
        ///
        /// - Parameter content: `MTORelationBuilder` 闭包，用于构建域与策略间的多对一关系。
        /// - Returns: 一个字典，Key为域的 ID，Value 为该域关联的策略查询对象 `QPolicy<Domain>`。
        public func createWithReturning(
            on transactor: Transactor? = nil,
            @MTORelationBuilder<PPolicy<Domain>, PDomain>
            _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>
        ) -> EventLoopRes<[UUID: [QPolicy<Domain>]], Errcase> {
            self.createWithReturning(relations: content(), on: transactor)
        }
        
        /// 批量创建裸域（无策略附带）。
        ///
        /// - Parameter domains: 一组准备落库的域对象。
        /// - Returns: 成功后返回携带数据库 UUID 的查询对象 `QDomain` 数组。
        ///
        /// ```swift
        /// let domains = try await system.domain.create(
        ///     domains: [.init(name: "DomainA", summary: "This is A")]
        /// ).get()
        /// ```
        public func create(
            domains: OrderedSet<PDomain>,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<[QDomain], Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建域权限 操作", metadata: ["domains": .summaryData(domains)])
            logger.debug("操作参数", metadata: ["domains": .data(domains)])
            let db = transactor?.db ?? self.db
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
        /// - Returns: `EventLoopRes<Void, Errcase>`
        public func delete(
            domainIds: OrderedSet<UUID>,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除域权限 操作", metadata: ["domainIds": .summaryData(domainIds)])
            logger.debug("操作参数", metadata: ["domainIds": .data(domainIds)])
            let db = transactor?.db ?? self.db
            return __delete(
                on: db,
                QDomain.self,
                ids: domainIds,
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
        /// - Parameter updater: 更新器对象 `PDomain.Updater`。
        /// - Returns: 更新完毕的域对象 `QDomain`。
        public func update(
            with updater: PDomain.Updater,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<QDomain, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新域权限 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新域权限 详细请求数据", metadata: ["data": .data(updater)])
            let db = transactor?.db ?? self.db
            return __update(
                on: db,
                updater: updater,
                label: "域权限",
                errThrowing: .domainUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.domainId) },
                dtoBuilder: { QDomain.make(from: $0) }
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
        relations: OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建域权限（含策略） 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        
        let db = transactor?.db ?? self.db
        
        return db.trans(throws: .domainCreateFailed, "数据库事务执行失败", category: .internal) { db in
            self.__create(on: db, domains: relations.mapToSet { $0.right }).flatMap { domains in
                self.policyController.__create(
                    on: db,
                    to: Domain.self,
                    relations: relations.enumeratedSet().mapToSet { .init(left: $0.element.left, right: domains[$0.offset].id) }
                )
            }
        }.map { logger.info("创建域权限（含策略） 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func createWithReturning(
        relations: OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<[UUID: [QPolicy<Domain>]], PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建域权限（含策略返回） 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        
        let db = transactor?.db ?? self.db
        
        return db.trans(throws: .domainCreateFailed, "数据库事务执行失败", category: .internal) { db in
            self.__create(on: db, domains: relations.mapToSet { $0.right }).flatMap { domains in
                self.policyController.__createWithReturning(
                    on: db,
                    to: Domain.self,
                    relations: relations.enumeratedSet().mapToSet { .init(left: $0.element.left, right: domains[$0.offset].id) }
                )
            }
        }.map {
            logger.info("创建域权限（含策略返回） 操作成功", metadata: ["data": .summaryData($0)])
            logger.debug("创建域权限（含策略返回） 结果详细数据", metadata: ["data": .data($0)])
            return $0
        }.logIfFail(logger: logger)
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
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainToUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(domainToUser: content(), on: transactor)
    }
    
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
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QUser>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(relations: content(), on: transactor)
    }
    
    /// 将一个或多个域指派给一个或多个群组。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func assign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(domainToGroup: content(), on: transactor)
    }
    
    /// 将一个或多个域指派给一个或多个群组。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func assign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QGroup>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(relations: content(), on: transactor)
    }
    
    // MARK: - 域权限撤销
    
    /// 撤销特定用户对某些域的指派关系。
    ///
    /// - Parameter content: 欲撤销的 `MTMRelationBuilder` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainFromUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(domainFromUser: content(), on: transactor)
    }
    
    /// 撤销特定用户对某些域的指派关系。
    ///
    /// - Parameter content: 欲撤销的 `MTMRelationBuilder` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QUser>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(relations: content(), on: transactor)
    }
    
    /// 撤销特定群组对某些域的指派关系。
    ///
    /// - Parameter content: 欲撤销的 `MTMRelationBuilder` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(domainFromGroup: content(), on: transactor)
    }
    
    /// 撤销特定群组对某些域的指派关系。
    ///
    /// - Parameter content: 欲撤销的 `MTMRelationBuilder` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QGroup>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(relations: content(), on: transactor)
    }
}

public extension PrivilegeSystem.DomainController {
    // MARK: - 域权限指派
    
    func assign(
        domainToUser relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限指派用户 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限指派用户关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToManyReversed(
            on: db,
            relations,
            type: (QDomain.self, QUser.self),
            action: .attach,
            label: "域权限与用户",
            errThrowing: .domainAssignUserFailed,
            pivotType: __SDBM.Pivots.UserDomain.self,
            checkList: .all
        )
        .map { logger.info("域权限指派用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func assign(
        relations: OrderedSet<MTMRelation<QDomain, QUser>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限指派用户 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限指派用户关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToManyReversed(
            on: db,
            relations,
            action: .attach,
            label: "域权限与用户",
            errThrowing: .domainAssignUserFailed,
            pivotType: __SDBM.Pivots.UserDomain.self
        )
        .map { logger.info("域权限指派用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func assign(
        domainToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限指派用户组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限指派用户组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            type: (QDomain.self, QGroup.self),
            action: .attach,
            label: "域权限与用户组",
            errThrowing: .domainAssignGroupFailed,
            pivotType: __SDBM.Pivots.DomainGroup.self,
            checkList: .all
        )
        .map { logger.info("域权限指派用户组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func assign(
        relations: OrderedSet<MTMRelation<QDomain, QGroup>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限指派用户组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限指派用户组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "域权限与用户组",
            errThrowing: .domainAssignGroupFailed,
            pivotType: __SDBM.Pivots.DomainGroup.self
        )
        .map { logger.info("域权限指派用户组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 域权限撤销
    
    func unassign(
        domainFromUser relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限撤销用户 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限撤销用户关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToManyReversed(
            on: db,
            relations,
            type: (QDomain.self, QUser.self),
            action: .detach,
            label: "域权限与用户",
            errThrowing: .domainUnassignUserFailed,
            pivotType: __SDBM.Pivots.UserDomain.self,
            checkList: .all
        )
        .map { logger.info("域权限撤销用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func unassign(
        relations: OrderedSet<MTMRelation<QDomain, QUser>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限撤销用户 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限撤销用户关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToManyReversed(
            on: db,
            relations,
            action: .detach,
            label: "域权限与用户",
            errThrowing: .domainUnassignUserFailed,
            pivotType: __SDBM.Pivots.UserDomain.self
        )
        .map { logger.info("域权限撤销用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func unassign(
        domainFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限撤销用户组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限撤销用户组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            type: (QDomain.self, QGroup.self),
            action: .detach,
            label: "域权限与用户组",
            errThrowing: .domainUnassignGroupFailed,
            pivotType: __SDBM.Pivots.DomainGroup.self,
            checkList: .all
        )
        .map { logger.info("域权限撤销用户组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func unassign(
        relations: OrderedSet<MTMRelation<QDomain, QGroup>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 域权限撤销用户组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("域权限撤销用户组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "域权限与用户组",
            errThrowing: .domainUnassignGroupFailed,
            pivotType: __SDBM.Pivots.DomainGroup.self
        )
        .map { logger.info("域权限撤销用户组 操作成功") }
        .logIfFail(logger: logger)
    }
}

extension PrivilegeSystem.DomainController {
    func __create(
        on db: PGDatabase,
        domains: OrderedSet<PDomain>
    ) -> EventLoopRes<[QDomain], PrivilegeSystem.Errcase> {
        __create(
            on: db,
            dtos: domains,
            label: "域权限",
            errThrowing: .domainCreateFailed,
            modelBuilder: { .success($0.raw()) },
            dtoBuilder: { QDomain.make(from: $0.fill()) }
        )
    }
}
