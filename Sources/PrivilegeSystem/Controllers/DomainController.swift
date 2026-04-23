import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule

extension PrivilegeSystem {
    public final class DomainController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        let policyController: PolicyController
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            policyController: PolicyController
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.policyController = policyController
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
            __create(on: db, domains: domains)
        }
        
        public func delete(
            domainIds: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                Role.self,
                ids: domainIds,
                allSatisfy: allSatisfy,
                label: "域权限",
                errThrowing: .domainDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ domainIds) }
            )
        }
        
        public func update(
            with updater: DTO.Domain<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Domain<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "域权限",
                errThrowing: .domainUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.domainId) },
                dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeSystem.DomainController {
    func create(
        relations: [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        db.trans { db in
            self.__create(on: db, domains: relations.map { $0.right }).flatMap { _ in
                self.policyController.__create(
                    on: db,
                    to: Domain.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
    }
    
    func createWithReturning(
        relations: [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) -> EventLoopRes<[UUID: [DTO.Policy<Domain, DTO.Queried>]], PrivilegeSystem.Errcase> {
        db.trans { db in
            self.__create(on: db, domains: relations.map { $0.right }).flatMap { _ in
                self.policyController.__createWithReturning(
                    on: db,
                    to: Domain.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
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
        __manyToMany(
            relations,
            action: .attach,
            label: "域权限与用户",
            errThrowing: .domainAssignUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
    }
    
    func assign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "域权限与用户组",
            errThrowing: .domainAssignGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
    }
    
    // MARK: - 域权限撤销
    
    func unassign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "域权限与用户",
            errThrowing: .domainUnassignUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
    }
    
    func unassign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "域权限与用户组",
            errThrowing: .domainUnassignGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
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
            dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0) }
        )
    }
}
