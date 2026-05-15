import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import PrivilegeModule

extension PrivilegeSystem {
    public final class PolicyController: SystemOPAController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        package let opa: OPA
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            opa: OPA
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.opa = opa
        }
        
        public func create<T: PolicyType>(
            to model: T.Type,
            @MTORelationBuilder<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            create(to: model, relations: content())
        }
        
        public func createWithReturning<T: PolicyType>(
            to model: T.Type,
            @MTORelationBuilder<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
        ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]], PrivilegeSystem.Errcase> {
            createWithReturning(to: model, relations: content())
        }
        
        public func delete<T: PolicyType>(
            from model: T.Type = T.self,
            policy: OTORelation<DTO.Policy<T, DTO.Queried>, T.Model.IDValue>
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            __deletePolicy(
                policy: policy,
                policyType: T.self,
                label: "权限策略",
                errThrowing: .policyDeleteFailed,
                filterBuilder: {
                    PolicyExp<T>
                        .query(on: $0)
                        .filter(\.$id == policy.left.id)
                },
                moduleId: { $0.left.moduleId },
                modelIdKey: \.right
            )
        }
    }
}

public extension PrivilegeSystem.PolicyController {
    func create<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __create(on: db, to: model, relations: relations)
    }
    
    func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]], PrivilegeSystem.Errcase> {
        __createWithReturning(on: db, to: model, relations: relations)
    }
}

extension PrivilegeSystem.PolicyController {
    func __create<T: PolicyType>(
        on db: PGDatabase,
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __createPolicy(
            on: db,
            relations: relations,
            policyType: T.self,
            label: "权限策略",
            errThrowing: .policyCreateFailed,
            policies: \.left,
            moduleId: \.moduleId,
            policyKey: \.policy,
            modelId: { pr, _ in pr.right },
            modelBuilder: { $0.raw(parentId: $1) }
        ).map { _ in }
    }
    
    func __createWithReturning<T: PolicyType>(
        on db: PGDatabase,
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]], PrivilegeSystem.Errcase> {
        __createPolicy(
            on: db,
            relations: relations,
            policyType: T.self,
            label: "权限策略",
            errThrowing: .policyCreateFailed,
            policies: \.left,
            moduleId: \.moduleId,
            policyKey: \.policy,
            modelId: { pr, _ in pr.right },
            modelBuilder: { $0.raw(parentId: $1) }
        ).flatMapThrowing { ps throws(PrivilegeSystem.Errcase.ErrType) in
            try required(throws: PrivilegeSystem.Errcase.policyCreateFailed, "Returning 解包失败", category: .internal) {
                try ps.grouped {
                    $0.$parent.id
                }.mapValues { v in
                    try v.map {
                        try DTO.Policy<T, DTO.Queried>.make(from: $0).get()
                    }
                }
            }
        }
    }
}
