import DTOBuilder
import Foundation
@preconcurrency import AnyCodable

public typealias GResource = GenericResource

public struct GenericResource: DTO.DBModel {
    public let id: UUID
    public let type: String
    public let appId: String
    public let data: [String: AnyCodable]
    public let createdAt: Date
    public let updatedAt: Date
    
    public static let logName: String = "GenericResource"
    
    package typealias SQLModel = __SDBM.AnyResource
    package let __m: SQLModel?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .type: .init(obj: self.type),
        .appId: .init(obj: self.appId),
        .data: .init(obj: self.data),
        .createdAt: .init(obj: self.createdAt),
        .updatedAt: .init(obj: self.updatedAt)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.id, .appId, .type] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case type
        case appId = "app_id"
        case data
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init<L, G>(resource: PM<L>.QResource<G>) {
        guard let m = Self.init(resource) else {
            fatalError("不允许将一个未从数据库中读取的模型强制转为 GResource")
        }
        self = m
    }
    
    public init?<L, G>(_ resource: PM<L>.QResource<G>) {
        guard let m = resource.__m else { return nil }
        self = Self.init(
            id: resource.id,
            type: resource.data.rtype.rawValue,
            appId: resource.data.appId,
            data: resource.data.json,
            createdAt: resource.createdAt,
            updatedAt: resource.updatedAt,
            model: .init(from: m)
        )
    }
    
    init(
        id: UUID,
        type: String,
        appId: String,
        data: [String: AnyCodable],
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.type = type
        self.appId = appId
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.appId = try container.decode(String.self, forKey: .appId)
        self.data = try container.decode([String: AnyCodable].self, forKey: .data)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.appId, forKey: .appId)
        try container.encode(self.data, forKey: .data)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }
}

extension GResource: __Model {}

public extension GResource {
    static func make(from model: __SDBM.AnyResource) -> Res<Self, Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            Self.init(
                id: try model.requireID(),
                type: model.type,
                appId: model.appId,
                data: model.data,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension GResource: Query.Queriable {
    public typealias Model = __SDBM.AnyResource
    public typealias ErrorType = Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        Self.idKey: \.$id,
        \.id: \.$id,
        \.appId: \.$appId,
        \.data: \.$data,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$id)
            .field(Model.self, \.$appId)
            .field(Model.self, \.$data)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

public extension GResource {
    static func testMake(
        id: UUID,
        type: String,
        appId: String,
        data: [String: AnyCodable],
        createdAt: Date = .init(),
        updatedAt: Date = .init()
    ) -> Self {
        .init(
            id: id,
            type: type,
            appId: appId,
            data: data,
            createdAt: createdAt,
            updatedAt: updatedAt,
            model: nil
        )
    }
}

public extension AnyResource {
    init(from resource: GResource) {
        self = Self.init(
            type: resource.type,
            appId: resource.appId,
            json: resource.data
        )
    }
}
