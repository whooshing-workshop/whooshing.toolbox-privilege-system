import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA

public extension PrivilegeModule {
    final class PrivilegeController: OPAController {
        package typealias E = Errcase
        
        package let db: PGDatabase
        package let eventLoop: EventLoop
        package let opa: OPA
        let moduleId: UUID
        
        init(
            db: PGDatabase,
            opa: OPA,
            moduleId: UUID,
            eventLoop: EventLoop
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.opa = opa
            self.moduleId = moduleId
        }
        
        public func create(
            privileges: [PrivilegeDTO<DTO.Prepare>]
        ) -> EventLoopRes<Void, Errcase> {
            __createPolicy(
                relations: privileges,
                policyType: "privilege",
                label: "资源权限",
                errThrowing: .privilegeCreateFailed,
                policies: { [$0] },
                moduleId: { _ in moduleId } ,
                policyKey: \.policy,
                modelId: { _, p in p.id },
                modelBuilder: { p, _ in p.raw() }
            ).map { _ in }
        }
        
        public func createWithReturning(
            privileges: [PrivilegeDTO<DTO.Prepare>]
        ) -> EventLoopRes<[PrivilegeDTO<DTO.Queried>], Errcase> {
            __createPolicy(
                relations: privileges,
                policyType: "privilege",
                label: "资源权限",
                errThrowing: .privilegeCreateFailed,
                policies: { [$0] },
                moduleId: { _ in moduleId } ,
                policyKey: \.policy,
                modelId: { _, p in p.id },
                modelBuilder: { p, _ in p.raw() }
            ).flatMapThrowing { ps throws(Errcase.ErrType) in
                try required(throws: Errcase.privilegeCreateFailed, "Returning 解包失败", category: .internal) {
                    try ps.map {
                        try PrivilegeDTO<DTO.Queried>.make(from: $0).get()
                    }
                }
            }
        }
        
        public func delete(
            policy: PrivilegeDTO<DTO.Queried>
        ) -> EventLoopRes<Void, Errcase> {
            __deletePolicy(
                policy: policy,
                policyType: "privilege",
                label: "资源权限",
                errThrowing: .privilegeDeleteFailed,
                filterBuilder: {
                    Privilege
                        .query(on: $0)
                        .filter(\.$id == policy.id)
                },
                moduleId: { _ in moduleId },
                modelIdKey: \.id
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
