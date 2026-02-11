import Fluent
import Foundation
import Policy
import ErrorHandle
import PrivilegeModule

public extension DTO {
    struct Policy<T: Status>: Sendable {
        public let moduleId: UUID
        public let policy: String
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updatedAt: Date
        
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
    func raw<G>(
        parentId: G.Model.IDValue,
        as type: G.Type = G.self
    ) -> PolicyExp<G> {
        let policy = PolicyExp<G>()
        policy.$parent.id = parentId
        policy.moduleId = moduleId
        policy.policy = self.policy
        return policy
    }
}

extension DTO.Policy where T == DTO.Queried {
    static func make<G>(from model: PolicyExp<G>) -> Res<Self, PrivilegeSystem.Errcase> {
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
