import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import Query
import DataConvertable
import LoggingAdvanced
@preconcurrency import AnyCodable

public struct AnyResourceDTO: DTOModel, Sendable {
    package typealias T = DTO.Queried
    
    public let id: UUID
    public let type: String
    public let name: String
    public let data: [String: AnyCodable]
    public let createdAt: Date
    public let updatedAt: Date
    
    package typealias AssociatedModel = AnyResource
    private let m: AssociatedModel?
    
    public init<T, G>(_ resource: PrivilegeModule<G>.ResourceDTO<T>) {
        self = Self.init(
            id: resource.id,
            name: resource.data.name,
            type: resource.data.rtype.rawValue,
            data: resource.data.json,
            createdAt: resource.createdAt,
            updatedAt: resource.updatedAt,
            model: .init(from: resource.model)
        )
    }
    
    init(
        id: UUID,
        name: String,
        type: String,
        data: [String: AnyCodable],
        createdAt: Date,
        updatedAt: Date,
        model: AssociatedModel?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.m = model
    }
    
    package var model: AnyResource {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: AnyResource) -> Res<Self, Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            Self.init(
                id: try model.requireID(),
                name: model.name,
                type: model.type,
                data: model.data,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension AnyResourceDTO: Query.Queriable {
    public typealias Model = AnyResource
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

extension AnyResourceDTO: Codable {}

// MARK: - Loggerable

extension AnyResourceDTO: Loggerable {
    public var logDescription: String {
        "AnyResource(id:\(id))"
    }
    public var summaryDescription: String {
        "AnyResource(\(id.shortString))"
    }
}
