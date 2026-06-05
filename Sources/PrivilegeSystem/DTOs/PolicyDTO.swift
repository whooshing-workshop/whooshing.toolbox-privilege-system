import Fluent
import Foundation
import Policy
import ErrorHandle
import PrivilegeModule
import Query
import DataConvertable
import LoggingAdvanced
import AnyCodable

public typealias PPolicy<G: PolicyType> = DTO.Policy<G, DTO.Prepare>
public typealias QPolicy<G: PolicyType> = DTO.Policy<G, DTO.Queried>

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

extension DTO.Policy: CustomStringConvertible, Loggerable {
    public var description: String {
        let isQueried = T.self == DTO.Queried.self
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? "\(self.id)" : nil),
            "module_id": AnyCodable("\(self.moduleId)"),
            "policy": AnyCodable(self.policy),
            "created_at": AnyCodable(isQueried ? "\(self.createdAt)" : nil),
            "updated_at": AnyCodable(isQueried ? "\(self.updatedAt)" : nil)
        ]

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
    
    public var summaryDescription: String {
        let isQueried = T.self == DTO.Queried.self
        return isQueried ?
            "Policy(\(id.shortString), module:\(moduleId.shortString))" :
            "Policy(module:\(moduleId))"
    }
}

extension DTO.Policy: Hashable {
    public func hash(into hasher: inout Hasher) {
        if T.self == DTO.Prepare.self {
            hasher.combine(moduleId)
            hasher.combine(policy)
        } else {
            hasher.combine(moduleId)
            hasher.combine(policy)
            hasher.combine(id)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if T.self == DTO.Prepare.self {
            lhs.moduleId == rhs.moduleId &&
            lhs.policy == rhs.policy
        } else {
            lhs.moduleId == rhs.moduleId &&
            lhs.policy == rhs.policy &&
            lhs.id == rhs.id &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
        }
    }
}

public extension DTO.Policy where T == DTO.Prepare {
    func like(_ rhs: QPolicy<G>) -> Bool {
        self.moduleId == rhs.moduleId &&
        self.policy == rhs.policy
    }
}

public extension DTO.Policy where T == DTO.Queried {
    func like(_ rhs: PPolicy<G>) -> Bool {
        self.moduleId == rhs.moduleId &&
        self.policy == rhs.policy
    }
}

public extension Collection {
    func like<C, T>(_ rhs: C) -> Bool where C: Collection, C.Element == QPolicy<T>, Element == PPolicy<T> {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection {
    func like<C, T>(_ rhs: C) -> Bool where C: Collection, C.Element == PPolicy<T>, Element == QPolicy<T> {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
