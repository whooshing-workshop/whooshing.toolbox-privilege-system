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
            @MTORelationBuilder<DTO.Policy<DTO.Prepare>, DTO.Domain<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            self.create(relations: content())
        }
        
        public func createWithReturning(
            @MTORelationBuilder<DTO.Policy<DTO.Prepare>, DTO.Domain<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
        ) -> EventLoopRes<[Int64: [DTO.Policy<DTO.Queried>]], Errcase> {
            self.createWithReturning(relations: content())
        }
        
        public func create(
            domains: [DTO.Domain<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Domain<DTO.Queried>], Errcase> {
            __create(
                dtos: domains,
                label: "域权限",
                errThrowing: .roleCreateFailed,
                modelBuilder: { $0.raw() },
                dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0) })
        }
        
        public func delete(
            roleIds: [Int64],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                Role.self,
                ids: roleIds,
                allSatisfy: allSatisfy,
                label: "域权限",
                errThrowing: .roleDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ roleIds) }
            )
        }
        
        public func update(
            with updater: DTO.Role<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Role<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "域权限",
                errThrowing: .roleUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.roleId) },
                dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeSystem.DomainController {
    func create(
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        db.trans { db in
            self.create(domains: relations.map { $0.right }).flatMap { _ in
                self.policyController.create(
                    to: Role.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
    }
    
    func createWithReturning(
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) -> EventLoopRes<[Int64: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
        db.trans { db in
            self.create(domains: relations.map { $0.right }).flatMap { _ in
                self.policyController.createWithReturning(
                    to: Role.self,
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
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
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
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
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
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
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
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
}
