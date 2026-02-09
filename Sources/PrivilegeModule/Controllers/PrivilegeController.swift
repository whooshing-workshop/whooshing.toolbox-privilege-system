import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

public extension PrivilegeModule {
    final class PrivilegeController: Controller {
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
        
        public func create(
            privileges: [PrivilegeDTO<DTO.Prepare>]
        ) -> EventLoopRes<[PrivilegeDTO<DTO.Queried>], Errcase> {
            __create(
                dtos: privileges,
                label: "资源权限",
                errThrowing: .privilegeCreateFailed,
                modelBuilder: { $0.raw() },
                dtoBuilder: { PrivilegeDTO<DTO.Queried>.make(from: $0) })
        }
        
        public func delete(
            ids: [Int64],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                Privilege.self,
                ids: ids,
                allSatisfy: allSatisfy,
                label: "资源权限",
                errThrowing: .privilegeDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ ids) }
            )
        }
        
        public func update(
            with updater: PrivilegeDTO<DTO.Prepare>.Updater
        ) -> EventLoopRes<PrivilegeDTO<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "资源权限",
                errThrowing: .privilegeUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.privilegeId) },
                dtoBuilder: { PrivilegeDTO<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    func attach(
        @MTMRelationBuilder<PM<ResourceList>.PrivilegeDTO<DTO.Queried>, PM<ResourceList>.AnyResourceDTO>
        _ content: @Sendable @escaping () -> [MTMRelation<PM<ResourceList>.PrivilegeDTO<DTO.Queried>, PM<ResourceList>.AnyResourceDTO>]
    ) -> EventLoopRes<Void, PM<ResourceList>.Errcase> {
        attach(relations: content())
    }
    
    // MARK: - 资源权限解除
    
    func detach(
        @MTMRelationBuilder<PM<ResourceList>.PrivilegeDTO<DTO.Queried>, PM<ResourceList>.AnyResourceDTO>
        _ content: @Sendable @escaping () -> [MTMRelation<PM<ResourceList>.PrivilegeDTO<DTO.Queried>, PM<ResourceList>.AnyResourceDTO>]
    ) -> EventLoopRes<Void, PM<ResourceList>.Errcase>  {
        detach(relations: content())
    }
}


public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    func attach(
        relations: [MTMRelation<PM<ResourceList>.PrivilegeDTO<DTO.Queried>, PM<ResourceList>.AnyResourceDTO>]
    ) -> EventLoopRes<Void, PM<ResourceList>.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "资源权限与资源",
            errThrowing: .privilegeAttachResourceFailed,
            siblingBuilder: { $0.model.$resources },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
    
    // MARK: - 资源权限解除
    
    func detach(
        relations: [MTMRelation<PM<ResourceList>.PrivilegeDTO<DTO.Queried>, PM<ResourceList>.AnyResourceDTO>]
    ) -> EventLoopRes<Void, PM<ResourceList>.Errcase>  {
        __manyToMany(
            relations,
            action: .detach,
            label: "资源权限与资源",
            errThrowing: .privilegeDetachResourceFailed,
            siblingBuilder: { $0.model.$resources },
            modelsBuilder: { self.db.eventLoop.makeSucceededResult($0.map { $0.model }) }
        )
    }
}
