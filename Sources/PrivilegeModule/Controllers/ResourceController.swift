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
        
        public func register<T: Resource>(
            type: T.Type
        ) -> EventLoopRes<Void, Errcase> where T.TypeList == ResourceList {
            T.Act.allCases.map {
                Action(
                    type: T.type,
                    name: $0.name,
                    description: $0.description,
                    code: $0.rawValue
                )
            }
            .create(on: db)
            .withError(Errcase.resourceRegisterFailed, "创建 Actions 时失败", category: .internal)
        }
        
        public func unregister<T: Resource>(
            type: T.Type
        ) -> EventLoopRes<Void, Errcase> where T.TypeList == ResourceList {
            Action.query(on: db)
                .filter(\.$type == T.type)
                .delete()
            .withError(Errcase.resourceUnregisterFailed, "删除 Actions 时失败", category: .internal)
        }
        
        public func create<T: Resource>(
            resources: [T]
        ) -> EventLoopRes<Void, Errcase> where T.TypeList == ResourceList {
            self.__create(
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
        ) -> EventLoopRes<Void, Errcase> where T.TypeList == ResourceList {
            __delete(
                T.self,
                ids: ids,
                allSatisfy: allSatisfy,
                label: "资源",
                errThrowing: .resourceDeleteFailed,
                fieldBuilder: { $0.field(\._$id) },
                filterBuilder: { $0.filter(\._$id ~~ ids) }
            )
        }
    }
}
