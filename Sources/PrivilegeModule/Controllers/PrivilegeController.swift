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
                        let path = self.policyPath(
                            moduleId: self.moduleId,
                            policyType: "privilege",
                            modelId: updater.privilegeId
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

// 资源权限的附加和解除
// 这些 API 不会进行存在性检测
// 需要调用者保证关系两端的记录均存在
public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    func attach<T: Resource>(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, T>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, T>]
    ) -> EventLoopRes<Void, S.Errcase> where T.TypeList == ResourceList {
        attach(relations: content())
    }
    
    // MARK: - 资源权限解除
    
    func detach<T: Resource>(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, T>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, T>]
    ) -> EventLoopRes<Void, S.Errcase> where T.TypeList == ResourceList {
        detach(relations: content())
    }
}

public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    func attach(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, S.AnyResource>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResource>]
    ) -> EventLoopRes<Void, S.Errcase> {
        attach(relations: content())
    }
    
    // MARK: - 资源权限解除
    
    func detach(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, S.AnyResource>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResource>]
    ) -> EventLoopRes<Void, S.Errcase> {
        detach(relations: content())
    }
}

public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    /// 附加权限动作要求资源与权限都必须已存在与数据库中
    /// 任一不存在都会导致失败
    func attach<T: Resource>(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, T>]
    ) -> EventLoopRes<Void, S.Errcase> where T.TypeList == ResourceList {
        db.trans { db in
            do {
                return try relations.map { relation in
                    try relation.left.flatMap { l in
                        try relation.right.map { r in
                            S.PrivilegeResourcePivot(
                                privilegeId: l.id,
                                resourceId: try required(throws: S.Errcase.privilegeAttachResourceFailed, "从 Resource 中获取 ID 失败", category: .external) {
                                    guard r._$idExists else {
                                        throw S.Errcase.privilegeAttachResourceFailed.d("该 Resource Id 不存在", category: .external)
                                    }
                                    return try r.requireID()
                                },
                                resourceType: T.type
                            )
                        }
                    }
                    .create(on: db)
                    .withError(S.Errcase.privilegeAttachResourceFailed, "创建 SQL 中间映射表失败", category: .internal)
                }.flatten(on: db.eventLoop)
            } catch {
                return self.eventLoop.makeFailedResult(error as! S.Errcase.ErrType)
            }
        }
    }
    
    // MARK: - 资源权限解除
    
    /// 解除权限动作的 Resource 无需从数据库中查得
    /// 可以实例化 T 类型的 Resource 并赋值 UUID
    func detach<T: Resource>(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, T>]
    ) -> EventLoopRes<Void, S.Errcase> where T.TypeList == ResourceList {
        db.trans { db in
            do {
                return try relations.flatMap { relation in
                    try relation.left.map { l in
                        guard !relation.right.isEmpty else {
                            return db.eventLoop.makeSucceededVoidResult()
                        }
                        
                        let ids = try relation.right.map { r in
                            try required(throws: S.Errcase.privilegeAttachResourceFailed, "从 Resource 中获取 ID 失败，该 Resource 并未经过数据库查询", category: .external) {
                                try r.requireID()
                            }
                        }
                        
                        return S.PrivilegeResourcePivot
                            .query(on: db)
                            .filter(\.$privilege.$id == l.id)
                            .filter(\.$resourceId ~~ ids)
                            .filter(\.$type == T.type)
                            .delete()
                            .withError(S.Errcase.privilegeDetachResourceFailed, "删除 SQL 中间映射表失败", category: .internal)
                    }
                }.flatten(on: db.eventLoop)
            } catch {
                return self.eventLoop.makeFailedResult(error as! S.Errcase.ErrType)
            }
        }
    }
}

public extension PrivilegeModule.PrivilegeController {
    // MARK: - 资源权限附加
    
    /// 附加权限动作要求资源与权限都必须已存在与数据库中
    /// 任一不存在都会导致失败
    func attach(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResource>]
    ) -> EventLoopRes<Void, S.Errcase> {
        db.trans { db in
            relations.map { relation in
                relation.left.flatMap { l in
                    relation.right.map { r in
                        S.PrivilegeResourcePivot(
                            privilegeId: l.id,
                            resourceId: r.id,
                            resourceType: r.type
                        )
                    }
                }
                .create(on: db)
                .withError(S.Errcase.privilegeAttachResourceFailed, "创建 SQL 中间映射表失败", category: .internal)
            }.flatten(on: db.eventLoop)
        }
    }
    
    // MARK: - 资源权限解除
    
    /// 解除权限动作的 Resource 无需从数据库中查得
    /// 可以实例化 AnyResource 类型的 Resource 并赋值 UUID
    func detach(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResource>]
    ) -> EventLoopRes<Void, S.Errcase> {
        db.trans { db in
            relations.flatMap { relation in
                relation.right.map { r in
                    guard !relation.left.isEmpty else {
                        return db.eventLoop.makeSucceededVoidResult()
                    }
                    
                    let ids = relation.left.map { $0.id }
                    
                    return S.PrivilegeResourcePivot
                        .query(on: db)
                        .filter(\.$privilege.$id ~~ ids)
                        .filter(\.$resourceId == r.id)
                        .filter(\.$type == r.type)
                        .delete()
                        .withError(S.Errcase.privilegeDetachResourceFailed, "删除 SQL 中间映射表失败", category: .internal)
                }
            }.flatten(on: db.eventLoop)
        }
    }
}
