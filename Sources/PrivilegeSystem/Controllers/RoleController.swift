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
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
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
    }
}
