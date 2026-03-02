import Fluent
import Foundation
import Policy
import ErrorHandle
import PrivilegeModule
import Query

public extension DTO {
    struct Policy<G: PolicyType, T: Status>: Sendable {
        public let moduleId: UUID
        public let policy: String
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var createdAt: Date
        @Passive public internal(set) var updatedAt: Date
        
        init(
            _moduleId: UUID,
            _policy: String
        ) {
            self.moduleId = _moduleId
            self.policy = _policy
        }
    }
}

public extension DTO.Policy where T == DTO.Prepare {
    init(
        moduleId: UUID,
        policy: String
    ) {
        self = Self.init(_moduleId: moduleId, _policy: policy)
    }
}

extension DTO.Policy where T == DTO.Prepare {
    /// 需要先存 Policy 到数据库中
    func raw(
        parentId: G.Model.IDValue
    ) -> PolicyExp<G> {
        let policy = PolicyExp<G>()
        policy.$parent.id = parentId
        policy.moduleId = moduleId
        policy.policy = self.policy
        return policy
    }
}

extension DTO.Policy where T == DTO.Queried {
    public static func make(from model: PolicyExp<G>) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .censorDTOFailed, category: .internal) {
            var n = Self.init(
                _moduleId: model.moduleId,
                _policy: model.policy
            )
            n.$id = try model.requireID()
            
            return n
        }
    }
}

extension DTO.Policy: Query.Queriable where T == DTO.Queried {
    public typealias Model = PolicyExp<G>
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.moduleId: \.$moduleId,
        \.policy: \.$policy,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$moduleId)
            .field(Model.self, \.$policy)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}
