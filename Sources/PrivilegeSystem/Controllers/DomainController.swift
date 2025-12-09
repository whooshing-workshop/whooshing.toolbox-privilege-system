import Fluent
import ACL
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    public struct DomainController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
        
        public func create(
            domains: [DTO.Domain<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Domain<DTO.Queried>], Errcase> {
            __createWithACL(
                models: domains,
                label: "域权限",
                errThrowing: .domainCreateFailed,
                aclBuilder: { $0.ast.toACL(Domain.self) },
                modelBuilder: { $0.raw(domainId: $1) },
                dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0) }
            )
        }
        
        public func delete(
            domainIds: Set<UUID>,
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                Domain.self,
                ids: domainIds,
                allSatisfy: allSatisfy,
                label: "域权限",
                errThrowing: .domainDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ domainIds) }
            )
        }
        
        public func update(
            info updater: DTO.Domain<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Domain<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "域权限",
                errThrowing: .domainUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.domainId) },
                dtoBuilder: { DTO.Domain<DTO.Queried>.make(from: $0) }
            )
        }
        
        // MARK: - 域权限指派
        
        public func assign(
            @RelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "域权限与用户",
                errThrowing: .domainAssignUserFailed,
                siblingBuilder: { $0.model.$users },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func assign(
            @RelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "域权限与用户组",
                errThrowing: .domainAssignGroupFailed,
                siblingBuilder: { $0.model.$groups },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        // MARK: - 域权限撤销
        
        public func unassign(
            @RelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "域权限与用户",
                errThrowing: .domainUnassignUserFailed,
                siblingBuilder: { $0.model.$users },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func unassign(
            @RelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "域权限与用户组",
                errThrowing: .domainUnassignGroupFailed,
                siblingBuilder: { $0.model.$groups },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
    }
}
