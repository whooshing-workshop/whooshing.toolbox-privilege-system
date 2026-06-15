import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import PgSQL
import Query
import Policy
import DataConvertable
import LoggingAdvanced
import NIOAdvanced
@preconcurrency import AnyCodable

public struct AnyResource: DTO.Model {
    public let id: UUID
    public let type: String
    public let name: String
    public let data: [String: AnyCodable]
    public let createdAt: Date
    public let updatedAt: Date
    
    package typealias SQLModel = __SDBM.AnyResource
    package let __m: SQLModel?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys : AnyCodable] {[
        .id: .init(self.id),
        .type: .init(self.type),
        .name: .init(self.name),
        .data: .init(self.data),
        .createdAt: .init(self.createdAt),
        .updatedAt: .init(self.updatedAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case type
        case name
        case data
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID,
        type: String,
        name: String,
        data: [String: AnyCodable],
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        self.data = try container.decode([String: AnyCodable].self, forKey: .data)
        self.createdAt = try container.decode(DateWrapper.self, forKey: .createdAt).date
        self.updatedAt = try container.decode(DateWrapper.self, forKey: .updatedAt).date
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.data, forKey: .data)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
        try container.encode(DateWrapper(self.updatedAt), forKey: .updatedAt)
    }
}

public extension AnyResource {
    static func make(from model: __SDBM.AnyResource) -> Res<Self, Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            Self.init(
                id: try model.requireID(),
                type: model.type,
                name: model.name,
                data: model.data,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

package extension AnyResource {
    func model(from db: PGDatabase) -> EventLoopRes<SQLModel, DTO.Errcase> {
        guard let m = __m else {
            return SQLModel.query(on: db)
                .filter(Self.idProperty == id)
                .first()
                .withError(DTO.Errcase.modelQueryFailed, category: .internal)
                .flatMap
            { res in
                guard let r = res else {
                    return db.eventLoop.makeFailedResult(DTO.Errcase.modelNotExist.d(category: .external))
                }
                return db.eventLoop.makeSucceededResult(r)
            }
        }
        return db.eventLoop.makeSucceededResult(m)
    }
}

extension AnyResource: Query.Queriable {
    public typealias Model = __SDBM.AnyResource
    public typealias ErrorType = Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
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
