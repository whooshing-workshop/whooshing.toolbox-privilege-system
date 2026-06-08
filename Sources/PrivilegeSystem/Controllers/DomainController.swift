import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    public final class DomainController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        let policyController: PolicyController
        
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
        
        public func create(
            @MTORelationBuilder<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            self.create(relations: content())
        }
        
        public func createWithReturning(
            @MTORelationBuilder<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
        ) -> EventLoopRes<[UUID: [DTO.Policy<Domain, DTO.Queried>]], Errcase> {
            self.createWithReturning(relations: content())
        }
        
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
    
    func assign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(relations: content())
    }
    
    func assign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        assign(relations: content())
    }
    
    // MARK: - 域权限撤销
    
    func unassign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        unassign(relations: content())
    }
    
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
