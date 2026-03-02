import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import Query
@preconcurrency import AnyCodable

public extension PM {
    struct AnyResourceDTO: Sendable {
        public let id: UUID
        public let data: [String: AnyCodable]
        public let createdAt: Date
        public let updatedAt: Date
        
        package typealias AssociatedModel = AnyResource
        private let m: AssociatedModel?
        
        public init<T>(_ resource: ResourceDTO<T, DTO.Queried>) {
            self = Self.init(
                id: resource.id,
                data: resource.data.json,
                createdAt: resource.createdAt,
                updatedAt: resource.updatedAt,
                model: .init(from: resource.model)
            )
        }
        
        init(id: UUID, data: [String: AnyCodable], createdAt: Date, updatedAt: Date, model: AssociatedModel?) {
            self.id = id
            self.data = data
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.m = model
        }
        
        var model: PM<ResourceList>.AnyResource {
            guard let m = m else {
                fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
            }
            return m
        }
        
        public static func make(from model: PM<ResourceList>.AnyResource) -> Res<Self, PrivilegeModule.Errcase> {
            .init(throws: .resourceDTOFailed, category: .internal) {
                Self.init(
                    id: try model.requireID(),
                    data: model.data,
                    createdAt: model.createdAt,
                    updatedAt: model.updatedAt,
                    model: model
                )
            }
        }
    }
}

extension PM.AnyResourceDTO: Query.Queriable {
    public typealias S = PM<ResourceList>
    public typealias Model = S.AnyResource
    public typealias ErrorType = S.Errcase
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
