import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import NIOConcurrencyHelpers
import PrivilegeModule

extension PrivilegeSystem {
    public final class PolicyController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        let opa: OPA
        
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
            from model: T.Type,
            policyIds: [UUID]
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                PolicyExp<T>.self,
                ids: policyIds,
                label: "权限策略",
                errThrowing: .policyDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ policyIds) }
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
        __create(to: model, relations: relations).map { _ in }
    }
    
    func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
        __create(to: model, relations: relations).flatMapThrowing { ps throws(PrivilegeSystem.Errcase.ErrType) in
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

extension PrivilegeSystem.PolicyController {
    func __create<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[PolicyExp<T>], PrivilegeSystem.Errcase> {
        var psData: [(id: String, content: String)] = []
        
        let ps = relations.flatMap {
            relation in relation.left.map {
                let path = getPolicyPath(
                    moduleId: $0.moduleId,
                    policyType: T.self,
                    modelId: relation.right
                )
                
                let policy = "package rules.\(path)\ndefault allow := false\n\n\($0.policy)"
                
                psData.append((path, policy))
                
                return $0.raw(parentId: relation.right, as: T.self)
            }
        }
        
        let policies = psData
        
        var res = eventLoop.makeSucceededVoidResult(throws: PrivilegeSystem.Errcase.ErrType.self)
        
        let progress = ProgressBox()
        
        for (id, content) in policies {
            res = res.flatMap { i in
                self.opa.policy.save(by: id, content: content)
                    .errCast(PrivilegeSystem.Errcase.policyCreateFailed, "OPA 策略插入失败", category: .internal)
                    .map
                { _ in
                    progress.increment()
                }
            }
        }
        
        return res.flatMap {
            ps
                .create(on: self.db)
                .withError(PrivilegeSystem.Errcase.policyCreateFailed, "数据库插入策略失败", category: .internal)
                .map { ps }
        }.flatMapError { error in
            undo(policies: policies, progress: progress).flatMap {
                self.eventLoop.makeFailedResult(error)
            }
        }
        
        @Sendable func undo(
            policies: [(id: String, content: String)],
            progress: ProgressBox
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            guard let p = progress.value else { return eventLoop.makeSucceededVoidResult() }
            var res = eventLoop.makeSucceededVoidResult(throws: PrivilegeSystem.Errcase.ErrType.self)
            for i in (0...p).reversed() {
                let (id, _) = policies[i]
                res = res.flatMap {
                    self.opa.policy.delete(of: id)
                        .errCast(PrivilegeSystem.Errcase.policyCreateFailed, "OPA 回退失败，产生策略残留", category: .internal)
                        .map { _ in }
                }
            }
            
            return res
        }
    }
    
    final class ProgressBox: @unchecked Sendable {
        private let lock = NIOLock()
        private var _value: Int? = nil
        
        var value: Int? {
            lock.withLock { _value }
        }
        
        func increment() {
            lock.withLock {
                _value = (_value == nil) ? 0 : (_value! + 1)
            }
        }
    }
}

extension PrivilegeSystem.PolicyController {
    func getPolicyPath<T: PolicyType>(
        moduleId: UUID,
        policyType: T.Type = T.self,
        modelId: T.Model.IDValue
    ) -> String {
        "m\(moduleId.hexString).\(T.typeId).id_\(modelId)"
    }
}
