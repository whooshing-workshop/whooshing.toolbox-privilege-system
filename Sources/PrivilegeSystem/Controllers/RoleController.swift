import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule

extension PrivilegeSystem {
    public final class RoleController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        let groupController: GroupController
        let policyController: PolicyController
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            groupController: GroupController,
            policyController: PolicyController
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.groupController = groupController
            self.policyController = policyController
        }
        
        public func create(
            @MTORelationBuilder<DTO.Policy<DTO.Prepare>, DTO.Role<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Role<DTO.Prepare>>]
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            self.create(relations: content())
        }
        
        public func createWithReturning(
            @MTORelationBuilder<DTO.Policy<DTO.Prepare>, DTO.Role<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Role<DTO.Prepare>>]
        ) -> EventLoopRes<[Int64: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
            self.createWithReturning(relations: content())
        }
        
        public func create(
            roles: [DTO.Role<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
            __create(
                dtos: roles,
                label: "角色",
                errThrowing: .roleCreateFailed,
                modelBuilder: { $0.raw() },
                dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0) })
        }
        
        public func delete(
            roleIds: [Int64],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                Role.self,
                ids: roleIds,
                allSatisfy: allSatisfy,
                label: "角色",
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
                label: "角色",
                errThrowing: .roleUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.roleId) },
                dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeSystem.RoleController {
    func create(
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        db.trans { db in
            self.create(roles: relations.map { $0.right }).flatMap { _ in
                self.policyController.create(
                    to: Role.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
    }
    
    func createWithReturning(
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) -> EventLoopRes<[Int64: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
        db.trans { db in
            self.create(roles: relations.map { $0.right }).flatMap { _ in
                self.policyController.createWithReturning(
                    to: Role.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
    }
}

public extension PrivilegeSystem.RoleController {
    // MARK: - 角色任命
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    // MARK: - 角色撤职
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
}

extension PrivilegeSystem.RoleController {
    // MARK: - 角色任命
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "角色与用户",
            errThrowing: .roleAppointUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "角色与用户组",
            errThrowing: .roleAppointGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "角色与群组内用户",
            errThrowing: .roleAppointGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "角色与群组内用户",
            errThrowing: .roleAppointGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { self.groupController.__query(relations: $0) }
        )
    }
    
    // MARK: - 角色撤职
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "角色与用户",
            errThrowing: .roleDismissUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "角色与用户组",
            errThrowing: .roleDismissGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "角色与群组内用户",
            errThrowing: .roleDismissGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "角色与群组内用户",
            errThrowing: .roleDismissGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { self.groupController.__query(relations: $0) }
        )
    }
}
