import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import Query
import SQLKit
import DataConvertable
import LoggingAdvanced
import ResourceMacros
import PgSQL
import NIOAdvanced
@preconcurrency import AnyCodable

public struct PDomain: DTO.Prepare {
    public typealias QueriedModel = QDomain
    public let id: UUID?
    public let name: String?
    public let description: String?
    
    public init(
        id: UUID? = nil,
        name: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
    }
    
    public var maps: [CodingKeys: AnyCodable] {[
        .id: .init(self.id),
        .name: .init(self.name),
        .description: .init(self.description)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case name
        case description
    }
}

public struct QDomain: DTO.Queried {
    public typealias PrepareModel = PDomain
    public let id: UUID
    public let name: String?
    public let description: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    package let __m: Domain?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys: AnyCodable] {[
        .id: .init(self.id),
        .name: .init(name),
        .description: .init(description),
        .createdAt: .init(self.createdAt),
        .updatedAt: .init(self.updatedAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID,
        name: String?,
        description: String?,
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.createdAt = try container.decode(DateWrapper.self, forKey: .createdAt).date
        self.updatedAt = try container.decode(DateWrapper.self, forKey: .updatedAt).date
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
        try container.encode(DateWrapper(self.updatedAt), forKey: .updatedAt)
    }
}

extension PDomain: __Prepare {
    package func raw() -> SQLModel {
        let domain = SQLModel()
        domain.id = id
        domain.name = name
        domain.description = description
        return domain
    }
}

extension QDomain: __Queried {
    package typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: Domain) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .domainDTOFailed, category: .internal) {
            try Self.init(
                id: model.requireID(),
                name: model.name,
                description: model.description,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension QDomain: Query.Queriable {
    public typealias Model = Domain
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.name: \.$name,
        \.description: \.$description,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}

    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$name)
            .field(Model.self, \.$description)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

// MARK: - Updater

public extension PDomain {
    struct Updater: @unchecked Sendable {
        public let domainId: UUID
        package var id: UUID { domainId }

        package let updates: OrderedDictionary<
            PartialKeyPath<PDomain>,
            (QueryBuilder<Domain>, QDomain?) throws -> QueryBuilder<Domain>
        >
        package let needsPeek: Bool

        public init(domainId: UUID) {
            self.domainId = domainId
            self.updates = [:]
            self.needsPeek = false
        }

        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<PDomain>,
                (QueryBuilder<Domain>, QDomain?) throws -> QueryBuilder<Domain>
            >,
            needsPeek: Bool
        ) {
            self.domainId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension PDomain.Updater: DTOUpdater {}

public extension PDomain.Updater {
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

public extension PDomain.Updater {
    func update(name: @escaping (QDomain) throws -> String) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }

    func update(description: @escaping (QDomain) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}
