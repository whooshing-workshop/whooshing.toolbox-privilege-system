import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import PgSQL
import Query
import ResourceMacros
import LoggingAdvanced
import AnyCodable
import NIOAdvanced
import DataConvertable
import DTOBuilder

public extension PM {
    struct QResource<G: Resource>: DTO.DBModel where G.ResourceType == ResourceList {
        public let id: UUID
        public let data: G
        public let createdAt: Date
        public let updatedAt: Date
        
        @Sibling(
            through: PrivilegeTResource<G>.self,
            from: \.resourceId,
            to: \.privilegeId
        )                                           public var privileges: [QPrivilege]
        
        public static var logName: String { "QResource" }
        
        public typealias S = PM<ResourceList>
        package typealias SQLModel = __DBM.ResourceModel<G>
        package let __m: SQLModel?
        package static var idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> { \.$id }
        
        public var maps: [CodingKeys: AnyHashable?] {[
            .id: .init(obj: self.id),
            .data: .init(obj: self.data),
            .createdAt: .init(obj: self.createdAt),
            .updatedAt: .init(obj: self.updatedAt),
            
            .privileges: .init(obj: self.$privileges)
        ]}
        
        public var summaryKeys: [CodingKeys] { [.id] }
        
        init(
            id: UUID,
            data: G,
            createdAt: Date,
            updatedAt: Date,
            model: SQLModel?
        ) {
            self.id = id
            self.data = data
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.__m = model
            
            self.$privileges.fromId = id
        }
    }
}

extension PM.QResource: __Model {}

extension PM.QResource: Codable {
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case data
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        
        case privileges
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = Self.init(
            id: try container.decode(UUID.self, forKey: .id),
            data: try container.decode(G.self, forKey: .data),
            createdAt: try container.decode(DateWrapper.self, forKey: .createdAt).date,
            updatedAt: try container.decode(DateWrapper.self, forKey: .updatedAt).date,
            model: nil
        )
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(data, forKey: .data)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
        try container.encode(DateWrapper(self.updatedAt), forKey: .updatedAt)
        
        try container.encode(privileges, forKey: .privileges)
    }
}

public extension PM.QResource {
    static func make(from model: S.__DBM.ResourceModel<G>) -> Res<Self, S.Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            try Self.init(
                id: model.requireID(),
                data: model.data,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension PM.QResource: Query.Queriable {
    public typealias Model = S.__DBM.ResourceModel<G>
    public typealias ErrorType = S.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        Self.idKey: \.$id,
        \.id: \.$id,
        \.data: \.$data,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$id)
            .field(Model.self, \.$data)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

// MARK: - Updater

public extension PM.QResource {
    struct Updater: @unchecked Sendable {
        public let resourceId: UUID
        package var id: UUID { resourceId }

        public typealias S = PM<ResourceList>
        
        package let updates: OrderedDictionary<
            AnyKeyPath,
            (QueryBuilder<SQLModel>, S.QResource<G>?) throws -> QueryBuilder<SQLModel>
        >
        package let needsPeek: Bool

        public init(resourceId: UUID) {
            self.resourceId = resourceId
            self.updates = [:]
            self.needsPeek = false
        }

        package init(
            id: UUID,
            updates: OrderedDictionary<
                AnyKeyPath,
                (QueryBuilder<SQLModel>, S.QResource<G>?) throws -> QueryBuilder<SQLModel>
            >,
            needsPeek: Bool
        ) {
            self.resourceId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension PM.QResource.Updater: DTOUpdater {}

public extension PM.QResource.Updater {
    func update(data: @escaping @autoclosure () throws -> G) -> Self {
        generate(key: \PM.QResource<G>.data) { builder, _ in
            builder.set(\.$data, to: try data())
        }
    }
}

public extension PM.QResource.Updater {
    func update<V: Encodable>(path: KeyPath<G, V>, value: @escaping (S.QResource<G>) throws -> V) -> Self {
        generate(needsPeek: true, key: path) { builder, data in
            guard let d = data else { fatalError("应当提供 Data 结果，却没有提供") }
            let field = PM<ResourceList>.__DBM.ResourceModel<G>.Fields().data
            return builder.set(
                [
                    field.key: .custom(
                        try jsonbSetSql(
                            field: field.name,
                            path: G.mirrors[path]!,
                            value: try value(d)
                        )
                    )
                ]
            )
        }
    }

    func update(data: @escaping (S.QResource<G>) throws -> G) -> Self {
        generate(needsPeek: true, key: \PM.QResource<G>.data) { builder, _data in
            guard let d = _data else { fatalError("应当提供 Data 结果，却没有提供") }
            return builder.set(\.$data, to: try data(d))
        }
    }
}

func jsonbSetSql<V: Encodable>(field: String, path: [String], value: V) throws -> SQLRaw {
    let data = try JSONEncoder().encode(value)
    
    let jsonString = String(data: data, encoding: .utf8) ?? ""
    let pathArray = "{\(path.joined(separator: ","))}"
    
    return .init("jsonb_set(\(field), '\(pathArray)', '\(jsonString)')")
}
