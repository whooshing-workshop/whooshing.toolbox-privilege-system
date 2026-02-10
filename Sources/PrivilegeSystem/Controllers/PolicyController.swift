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
            system: PrivilegeSystem,
            opa: OPA
        ) {
            self.db = system.db
            self.eventLoop = system.eventLoop
            self.opa = opa
        }
        
        public func create<T: PolicyType>(
            to model: T.Type,
            @MTORelationBuilder<DTO.Policy<DTO.Prepare>, T.Model.IDValue>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            create(to: model, relations: content())
        }
        
        public func createWithReturning<T: PolicyType>(
            to model: T.Type,
            @MTORelationBuilder<DTO.Policy<DTO.Prepare>, T.Model.IDValue>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
        ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
            createWithReturning(to: model, relations: content())
        }
        
        public func delete<T: PolicyType>(
            from model: T.Type = T.self,
            policy: OTORelation<DTO.Policy<DTO.Queried>, T.Model.IDValue>
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            __deletePolicy(
                policy: policy,
                policyType: T.typeId,
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
        
        public func check(
            policy: DTO.Policy<DTO.Prepare>
        ) -> EventLoopRes<Result<OPA.Answer<OPA.NULL>, OPA.Err>, Errcase> {
            check(policy: policy.policy)
        }
        
        public func check(
            policy: String
        ) -> EventLoopRes<Result<OPA.Answer<OPA.NULL>, OPA.Err>, Errcase> {
            opa.policy.check(policy: policy)
                .errCast(PrivilegeSystem.Errcase.policyCheckFailed, category: .internal)
        }
        
        public func check(
            policies: [String]
        ) -> EventLoopRes<[Result<OPA.Answer<OPA.NULL>, OPA.Err>], Errcase> {
            policies.map {
                opa.policy.check(policy: $0)
                    .errCast(PrivilegeSystem.Errcase.policyCheckFailed, category: .internal)
            }.flatten(on: eventLoop)
        }
        
        public func check(
            policies: [DTO.Policy<DTO.Prepare>]
        ) -> EventLoopRes<[Result<OPA.Answer<OPA.NULL>, OPA.Err>], Errcase> {
            policies.map {
                opa.policy.check(policy: $0.policy)
                    .errCast(PrivilegeSystem.Errcase.policyCheckFailed, category: .internal)
            }.flatten(on: eventLoop)
        }
    }
}

public extension PrivilegeSystem.PolicyController {
    func create<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __createPolicy(
            relations: relations,
            policyType: T.typeId,
            label: "权限策略",
            errThrowing: .policyCreateFailed,
            policies: \.left,
            moduleId: \.moduleId,
            policyKey: \.policy,
            modelId: { pr, _ in pr.right },
            modelBuilder: { $0.raw(parentId: $1, as: model) }
        ).map { _ in }
    }
    
    func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
        __createPolicy(
            relations: relations,
            policyType: T.typeId,
            label: "权限策略",
            errThrowing: .policyCreateFailed,
            policies: \.left,
            moduleId: \.moduleId,
            policyKey: \.policy,
            modelId: { pr, _ in pr.right },
            modelBuilder: { $0.raw(parentId: $1, as: model) }
        ).flatMapThrowing { ps throws(PrivilegeSystem.Errcase.ErrType) in
            try required(throws: PrivilegeSystem.Errcase.policyCreateFailed, "Returning 解包失败", category: .internal) {
                try ps.grouped {
                    $0.$parent.id
                }.mapValues { v in
                    try v.map {
                        try DTO.Policy<DTO.Queried>.make(from: $0).get()
                    }
                }
            }
        }
    }
}
