import Fluent
import ACL
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    public struct RoleController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        let groupController: GroupController
        
        init(
            system: PrivilegeSystem,
            groupController: GroupController
        ) {
            self.db = system.db
            self.eventLoop = system.eventLoop
            self.groupController = groupController
        }
        
        public func create(
            roles: [DTO.Role<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
            __createWithACL(
                models: roles,
                label: "角色",
                errThrowing: .roleCreateFailed,
                aclBuilder: { $0.ast.toACL(Role.self) },
                modelBuilder: { $0.raw(aclId: $1) },
                dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0) }
            )
        }
        
        public func delete(
            roleIds: Set<UUID>,
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
            info updater: DTO.Role<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Role<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "角色",
                errThrowing: .roleUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.roleId) },
                dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0) }
            )
        }
        
        // MARK: - 角色任命
        
        public func appoint(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "角色与用户",
                errThrowing: .roleAppointUserFailed,
                siblingBuilder: { $0.model.$users },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func appoint(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "角色与用户组",
                errThrowing: .roleAppointGroupFailed,
                siblingBuilder: { $0.model.$groups },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func appoint(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "角色与群组内用户",
                errThrowing: .roleAppointGroupUserFailed,
                siblingBuilder: { $0.model.$usersInGroup },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func appoint(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "角色与群组内用户",
                errThrowing: .roleAppointGroupUserFailed,
                siblingBuilder: { $0.model.$usersInGroup },
                modelsBuilder: { groupController.__query(relations: $0) }
            )
        }
        
        // MARK: - 角色撤职
        
        public func dismiss(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "角色与用户",
                errThrowing: .roleDismissUserFailed,
                siblingBuilder: { $0.model.$users },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func dismiss(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "角色与用户组",
                errThrowing: .roleDismissGroupFailed,
                siblingBuilder: { $0.model.$groups },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func dismiss(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "角色与群组内用户",
                errThrowing: .roleDismissGroupUserFailed,
                siblingBuilder: { $0.model.$usersInGroup },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func dismiss(
            @RelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "角色与群组内用户",
                errThrowing: .roleDismissGroupUserFailed,
                siblingBuilder: { $0.model.$usersInGroup },
                modelsBuilder: { groupController.__query(relations: $0) }
            )
        }
        
    }
}
