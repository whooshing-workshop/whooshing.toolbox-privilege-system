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
    }
}
