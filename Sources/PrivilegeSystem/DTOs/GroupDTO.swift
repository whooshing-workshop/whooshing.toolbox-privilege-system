import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import SQLKit
import Query
import DataConvertable
import LoggingAdvanced
import AnyCodable
import ResourceMacros

public struct PGroup: DTO.Prepare {
    public typealias QueriedModel = QGroup
    public let id: UUID?
    public let name: String
    public let parentId: UUID?
    public let description: String?
    
    public init(
        id: UUID? = nil,
        name: String,
        parentId: UUID? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.description = description
    }
    
    public var maps: [CodingKeys : AnyCodable] {[
        .id: .init(self.id),
        .name: .init(self.name),
        .parentId: .init(self.parentId),
        .description: .init(self.description)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case name
        case parentId = "parent_id"
        case description
    }
}

public struct QGroup: DTO.Queried {
    public typealias PrepareModel = PGroup
    public let id: UUID
    public let name: String
    public let parentId: UUID?
    public let description: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    package let __m: __SDBM.Group?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys : AnyCodable] {[
        .id: .init(self.id),
        .name: .init(self.name),
        .parentId: .init(self.parentId),
        .description: .init(self.description),
        .createdAt: .init(self.createdAt),
        .updatedAt: .init(self.updatedAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case name
        case parentId = "parent_id"
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID,
        name: String,
        parentId: UUID?,
        description: String?,
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.parentId, forKey: .parentId)
        try container.encodeIfPresent(self.description, forKey: .description)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }
}

extension PGroup: __Prepare {
    func raw() -> SQLModel {
        let group = SQLModel()
        group.id = id
        group.$parent.id = parentId
        group.name = name
        group.description = description
        return group
    }
}

extension QGroup: __Queried {
    package typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: __SDBM.Group) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .groupDTOFailed, category: .internal) {
            try Self.init(
                id: model.requireID(),
                name: model.name,
                parentId: model.$parent.id,
                description: model.description,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension QGroup: Query.Queriable {
    public typealias Model = __SDBM.Group
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.parentId: \.$parent.$id,
        \.name: \.$name,
        \.description: \.$description,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt,
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$parent.$id)
            .field(Model.self, \.$name)
            .field(Model.self, \.$description)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

// MARK: - Updater

public extension PGroup {
    struct Updater: @unchecked Sendable {
        public let groupId: UUID
        package var id: UUID { groupId }

        package let updates: OrderedDictionary<
            PartialKeyPath<PGroup>,
            (QueryBuilder<__SDBM.Group>, QGroup?) throws -> QueryBuilder<__SDBM.Group>
        >
        package let needsPeek: Bool

        public init(groupId: UUID) {
            self.groupId = groupId
            self.updates = [:]
            self.needsPeek = false
        }

        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<PGroup>,
                (QueryBuilder<__SDBM.Group>, QGroup?) throws -> QueryBuilder<__SDBM.Group>
            >,
            needsPeek: Bool
        ) {
            self.groupId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension PGroup.Updater: DTOUpdater {}

public extension PGroup.Updater {
    func update(name: @escaping @autoclosure () throws -> String) -> Self {
        generate(key: \.name) { builder, _ in
            builder.set(\.$name, to: try name())
        }
    }

    func update(description: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.description) { builder, _ in
            builder.set(\.$description, to: try description())
        }
    }
}

public extension PGroup.Updater {
    func update(name: @escaping (QGroup) throws -> String) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }

    func update(description: @escaping (QGroup) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}
