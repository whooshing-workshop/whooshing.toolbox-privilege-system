import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

public extension PrivilegeModule {
    final class ResourceController: ModuleController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop
        ) {
            self.db = db
            self.eventLoop = eventLoop
        }
        
        public func create<T: Resource>(
            resources: [DTO.Resource<T, DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Resource<T, DTO.Queried>], Errcase> {
            __create(
                dtos: resources,
                label: "资源",
                errThrowing: .resourceCreateFailed,
                modelBuilder: { $0.raw() },
                dtoBuilder: { DTO.Resource<T, DTO.Queried>.make(from: $0) })
        }
        
        public func delete(
            ids: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                ResourceModel<AnyResource>.self,
                ids: ids,
                allSatisfy: allSatisfy,
                label: "资源",
                errThrowing: .resourceDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ ids) }
            )
        }
        
        public func update<T: Resource>(
            with updater: DTO.Resource<T, DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Resource<T, DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "资源",
                errThrowing: .resourceUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.resourceId) },
                dtoBuilder: { DTO.Resource<T, DTO.Queried>.make(from: $0) }
            )
        }
    }
}
