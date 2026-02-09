import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
@preconcurrency import AnyCodable

public extension PM {
    struct AnyResourceDTO: Sendable {
        public let id: UUID
        public let resource: [String: AnyCodable]
        public let createdAt: Date
        public let updateAt: Date
        
        package typealias AssociatedModel = AnyResource
        private let m: AssociatedModel?
        
        public init<T>(_ resource: ResourceDTO<T, DTO.Queried>) {
            self = Self.init(
                id: resource.id,
                resource: resource.resource.json,
                createdAt: resource.createdAt,
                updateAt: resource.updateAt,
                model: .init(from: resource.model)
            )
        }
        
        init(id: UUID, resource: [String: AnyCodable], createdAt: Date, updateAt: Date, model: AssociatedModel?) {
            self.id = id
            self.resource = resource
            self.createdAt = createdAt
            self.updateAt = updateAt
            self.m = model
        }
        
        var model: PM<ResourceList>.AnyResource {
            guard let m = m else {
                fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
            }
            return m
        }
        
        static func make(from model: PM<ResourceList>.AnyResource) -> Res<Self, PrivilegeModule.Errcase> {
            .init(throws: .resourceDTOFailed, category: .internal) {
                Self.init(
                    id: try model.requireID(),
                    resource: model.data,
                    createdAt: model.createdAt,
                    updateAt: model.updatedAt,
                    model: model
                )
            }
        }
    }
}
