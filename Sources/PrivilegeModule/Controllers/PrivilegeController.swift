import Fluent
import Policy
import Vapor
import PgSQL
import SQLKit
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
        
        public typealias S = PM<ResourceList>
        
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
                policyType: Privilege.self,
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
                policyType: Privilege.self,
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
                policyType: Privilege.self,
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
            guard updater.updates.count > 0 else {
                return db.eventLoop.makeFailedResult(Errcase.privilegeUpdateFailed, "没有任何数据需要更新", category: .external)
            }
            
            // 在 SQL 事务中，先执行 SQL 更新，保持该事务会话
            // 只有当 OPA 也更新成功后才提交事务
            // 否则，无论 SQL 或 OPA 更新失败，数据库会进行回滚
            // 而 OPA 无需进行回滚，因为仅处理一条策略数据，
            // 更新失败意味着其仍保留原数据在 OPA 中
            return db.trans { db in
                // 先对一般字段进行更新: name, description
                // 这些字段无需额外的评估
                self.__update(
                    updater: updater,
                    allowEmpty: true,
                    label: "资源权限",
                    errThrowing: .privilegeUpdateFailed,
                    filterBuilder: { $0.filter(\.$id == updater.privilegeId) },
                    dtoBuilder: { PrivilegeDTO<DTO.Queried>.make(from: $0) }
                ).flatMap { updateRes in
                    guard let policyUpdater = updater.policyUpdate else {
                        return self.eventLoop.makeSucceededResult(updateRes)
                    }
                    
                    // 对策略进行修改，如果授意如此的话
                    // 如果此处策略修改失败，抛出错误导致数据库事务失败
                    // 则数据库也会回滚，而 OPA 无需进行回滚
                    // 更新失败意味着其仍保留原数据在 OPA 中
                    // 保证了数据库与 OPA 数据完全同步
                    let policy: String
                    do {
                        policy = try policyUpdater(updater.needsPeek ? updateRes : nil)
                    } catch {
                        return self.eventLoop.makeFailedResult(Errcase.privilegeUpdateFailed, "取得要更新的 Policy 失败", category: .external)
                    }
                    
                    return Privilege
                        .query(on: db)
                        .filter(\.$id == updater.privilegeId)
                        .set(\.$policy, to: policy)
                        .update()
                        .withError(Errcase.privilegeUpdateFailed, "资源权限策略 SQL 更新失败", category: .internal)
                        .flatMap
                    {
                        let path = policyPath(
                            moduleId: self.moduleId,
                            modelId: updater.privilegeId,
                            type: Privilege.self,
                            format: .route
                        )
                        
                        return self.opa.policy.save(by: path, content: policy)
                            .errCast(Errcase.privilegeUpdateFailed, "资源权限策略 OPA 更新失败", category: .internal)
                            .map { _ in updateRes }
                    }
                }
            }
        }
    }
}

public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    func attach(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) -> EventLoopRes<Void, S.Errcase> {
        attach(relations: content())
    }
    
    // MARK: - 资源权限解除
    
    func detach(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) -> EventLoopRes<Void, S.Errcase>  {
        detach(relations: content())
    }
}


public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    /// 附加权限动作要求资源与权限都必须已存在与数据库中
    /// 任一不存在都会导致失败
    func attach(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) -> EventLoopRes<Void, S.Errcase> {
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
    
    /// 解除权限动作的 Resource 无需从数据库中查得
    /// 可以实例化 AnyResource 类型的 Resource 并赋值 UUID
    func detach(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) -> EventLoopRes<Void, S.Errcase>  {
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
