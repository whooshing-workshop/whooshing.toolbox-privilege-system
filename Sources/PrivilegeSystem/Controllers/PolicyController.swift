import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    public final class PolicyController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        
        init(
            system: PrivilegeSystem,
        ) {
            self.db = system.db
            self.eventLoop = system.eventLoop
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
            policyIds: Set<UUID>
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
    }
}

public extension PrivilegeSystem.PolicyController {
    func create<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        relations.flatMap {
            relation in relation.left.map {
                $0.raw(parentId: relation.right, as: T.self)
            }
        }
        .create(on: db)
        .withError(PrivilegeSystem.Errcase.policyCreateFailed, "插入策略失败", category: .internal)
    }
    
    func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<DTO.Prepare>, T.Model.IDValue>]
    ) -> EventLoopRes<[T.Model.IDValue: [DTO.Policy<DTO.Queried>]], PrivilegeSystem.Errcase> {
        let ps = relations.flatMap {
            relation in relation.left.map {
                $0.raw(parentId: relation.right, as: T.self)
            }
        }
        
        return ps
            .create(on: db)
            .withError(PrivilegeSystem.Errcase.policyCreateFailed, "插入策略失败", category: .internal)
            .flatMapThrowing
        { () throws(PrivilegeSystem.Errcase.ErrType) in
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
