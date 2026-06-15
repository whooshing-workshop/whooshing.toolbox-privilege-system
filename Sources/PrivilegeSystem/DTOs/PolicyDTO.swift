import Fluent
import Foundation
import Policy
import ErrorHandle
import PrivilegeModule
import Query
import DataConvertable
import LoggingAdvanced
import AnyCodable
import ResourceMacros

public struct PPolicy<G: PolicyType>: DTO.Prepare {
    public typealias QueriedModel = QPolicy<G>
    public let id: UUID?
    public let moduleId: UUID
    public let policy: String
    
    public init(
        id: UUID? = nil,
        moduleId: UUID,
        policy: String
    ) {
        self.id = id
        self.moduleId = moduleId
        self.policy = policy
    }
    
    public var maps: [CodingKeys : AnyCodable] {[
        .id: .init(self.id),
        .moduleId: .init(self.moduleId),
        .policy: .init(self.policy)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case moduleId = "module_id"
        case policy
    }
}

public struct QPolicy<G: PolicyType>: DTO.Queried {
    public typealias PrepareModel = PPolicy<G>
    public let id: UUID
    public let moduleId: UUID
    public let policy: String
    public let createdAt: Date
    public let updatedAt: Date
    
    package let __m: PolicyExp<G>?
    package static var idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> { \.$id }
    
    public var maps: [CodingKeys : AnyCodable] {[
        .id: .init(self.id),
        .moduleId: .init(self.moduleId),
        .policy: .init(self.policy),
        .createdAt: .init(self.createdAt),
        .updatedAt: .init(self.updatedAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case moduleId = "module_id"
        case policy
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID,
        moduleId: UUID,
        policy: String,
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.moduleId = moduleId
        self.policy = policy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.moduleId = try container.decode(UUID.self, forKey: .moduleId)
        self.policy = try container.decode(String.self, forKey: .policy)
        self.createdAt = try container.decode(DateWrapper.self, forKey: .createdAt).date
        self.updatedAt = try container.decode(DateWrapper.self, forKey: .updatedAt).date
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: QPolicy<G>.CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.moduleId, forKey: .moduleId)
        try container.encode(self.policy, forKey: .policy)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }
}

extension PPolicy: __Prepare {
    /// 需要先存 Policy 到数据库中
    package func raw(parentId: G.Model.IDValue) -> SQLModel {
        let policy = PolicyExp<G>()
        policy.id = id
        policy.$parent.id = parentId
        policy.moduleId = moduleId
        policy.policy = self.policy
        return policy
    }
}

extension QPolicy: __Queried {
    package typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: PolicyExp<G>) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .policyDTORawCreateFailed, category: .internal) {
            Self.init(
                id: try model.requireID(),
                moduleId: model.moduleId,
                policy: model.policy,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension QPolicy: Query.Queriable {
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
