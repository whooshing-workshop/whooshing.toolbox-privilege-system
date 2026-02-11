import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

public extension PrivilegeModule {
    final class ResourceController: Controller {
        package typealias E = Errcase
        
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
            resources: [T]
        ) -> EventLoopRes<Void, Errcase> where T.T == ResourceList {
            __create(
                dtos: resources,
                label: "资源",
                errThrowing: .resourceCreateFailed,
                modelBuilder: { $0 },
                dtoBuilder: { .success($0) }
            ).map { _ in }
        }
        
        public func delete<T: Resource>(
            ids: [T.IDValue],
            allSatisfy: Bool = true,
            of type: T.Type = T.self
        ) -> EventLoopRes<Void, Errcase> where T.T == ResourceList {
            __delete(
                T.self,
                ids: ids,
                allSatisfy: allSatisfy,
                label: "资源",
                errThrowing: .resourceDeleteFailed,
                fieldBuilder: { $0.field(T.idKey) },
                filterBuilder: { $0.filter(T.idKey ~~ ids) }
            )
        }
    }
}
