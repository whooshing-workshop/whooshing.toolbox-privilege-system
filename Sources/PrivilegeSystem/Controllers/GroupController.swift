import Fluent
import ACL
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    public struct GroupController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
        
        public func create(
            groups: [DTO.Group<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
            db.trans { db in
                let gs = groups.map { $0.raw() }
                return gs
                    .create(on: db)
                    .withError(Errcase.groupCreateFailed, "创建群组时失败", category: .internal)
                    .flatMapThrowing
                { () throws(Errcase.ErrType) in
                    try gs.map { g throws(Errcase.ErrType) in try DTO.Group<DTO.Queried>.make(from: g).get() }
                }
            }
        }
        
        public func delete(
            groupIds: Set<UUID>,
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                UGroup.self,
                ids: groupIds,
                allSatisfy: allSatisfy,
                label: "用户群组",
                errThrowing: .groupDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ groupIds) }
            )
        }
        
        public func update(
            info updater: DTO.Group<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Group<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户群组",
                errThrowing: .groupUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.groupId) },
                dtoBuilder: { DTO.Group<DTO.Queried>.make(from: $0) }
            )
        }
    }
}
