import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    public final class PolicyController: SystemOPAController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        package let opa: OPA
        
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            opa: OPA,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.opa = opa
            self.logger = logger
        }
        
        public func create<T: PolicyType>(
            to model: T.Type,
            @MTORelationBuilder<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建策略 操作", metadata: ["type": .string(String(describing: model))])
            return create(to: model, relations: content())
                .map { logger.info("创建策略 操作成功") }
                .logIfFail(logger: logger)
        }
        
        public func createWithReturning<T: PolicyType>(
            to model: T.Type,
            @MTORelationBuilder<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
        ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]], PrivilegeSystem.Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建策略（返回） 操作", metadata: ["type": .string(String(describing: model))])
            return createWithReturning(to: model, relations: content())
                .map { logger.info("创建策略（返回） 操作成功"); return $0 }
                .logIfFail(logger: logger)
        }
        
        public func delete<T: PolicyType>(
            from model: T.Type = T.self,
            policy: OTORelation<DTO.Policy<T, DTO.Queried>, T.Model.IDValue>
        ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除策略 操作", metadata: ["type": .string(String(describing: model)), "policyId": .stringConvertible(policy.left.id)])
            return __deletePolicy(
                on: db,
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
            .map { logger.info("删除策略 操作成功") }
            .logIfFail(logger: logger)
        }
    }
}

public extension PrivilegeSystem.PolicyController {
    func create<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建策略（数组） 操作", metadata: ["type": .string(String(describing: model)), "relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return __create(on: db, to: model, relations: relations)
            .map { _ in logger.info("创建策略（数组） 操作成功") }
            .logIfFail(logger: logger)
    }
    
    func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]], PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建策略（数组返回） 操作", metadata: ["type": .string(String(describing: model)), "relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return __createWithReturning(on: db, to: model, relations: relations)
            .map { logger.info("创建策略（数组返回） 操作成功"); return $0 }
            .logIfFail(logger: logger)
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
