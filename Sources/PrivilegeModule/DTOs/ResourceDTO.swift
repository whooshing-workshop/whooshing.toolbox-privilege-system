import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit

public extension PM {
    struct ResourceDTO<G: Resource, T: DTO.Status>: Sendable where G.ResourceType == ResourceList {
        let resource: G
        
        @DTO.Passive() public internal(set) var id: UUID
        @DTO.Passive() public internal(set) var createdAt: Date
        @DTO.Passive() public internal(set) var updateAt: Date
        
        package typealias AssociatedModel = PM<ResourceList>.ResourceModel<G>
        private let m: AssociatedModel?
        
        init(
            _resource: G,
            _model: AssociatedModel?
        ) {
            self.resource = _resource
            self.m = _model
        }
    }
}

public extension PM.ResourceDTO where T == DTO.Prepare {
    init(
        resource: G
    ) {
        self = Self.init(_resource: resource, _model: nil)
    }
}

extension PM.ResourceDTO where T == DTO.Queried {
    var model: PM<ResourceList>.ResourceModel<G> {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: PM<ResourceList>.ResourceModel<G>) -> Res<Self, PrivilegeModule.Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            var n = Self.init(
                _resource: model.data,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updateAt = model.updatedAt
            return n
        }
    }
}

extension PM.ResourceDTO where T == DTO.Prepare {
    func raw() -> PM<ResourceList>.ResourceModel<G> {
        .init(from: resource)
    }
}

public extension PM.ResourceDTO where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let resourceId: UUID
        package var id: UUID { resourceId }
        
        package private(set) var updates: OrderedDictionary<
            AnyKeyPath,
            (QueryBuilder<AssociatedModel>, PM<ResourceList>.ResourceDTO<G, DTO.Queried>?) throws -> QueryBuilder<AssociatedModel>
        > = [:]
        
        package private(set) var needsPeek = false
        
        public init(resourceId: UUID) {
            self.resourceId = resourceId
        }
    }
}

extension PM.ResourceDTO.Updater: DTOUpdater {}

public extension PM.ResourceDTO.Updater {
    mutating
    func update<V: Encodable>(path: KeyPath<G, V>, value: @escaping @autoclosure () throws -> V) {
        updates[path] = { builder, _ in
            let field = PM<ResourceList>.ResourceModel<G>.Fields().data
            return builder.set(
                [
                    field.key: .custom(
                        try jsonbSetSql(
                            field: field.name,
                            path: G.mirrors[path]!,
                            value: try value()
                        )
                    )
                ]
            )
        }
    }
    
    mutating
    func update(data: @escaping @autoclosure () throws -> G) {
        updates[\PM.ResourceDTO<G, T>.resource] = { builder, _ in
            builder.set(\.$data, to: try data())
        }
    }
}

public extension PM.ResourceDTO.Updater {
    mutating
    func update<V: Encodable>(path: KeyPath<G, V>, value: @escaping (PM<ResourceList>.ResourceDTO<G, DTO.Queried>) throws -> V) {
        needsPeek = true
        updates[path] = { builder, data in
            guard let d = data else { fatalError("应当提供 Data 结果，却没有提供") }
            let field = PM<ResourceList>.ResourceModel<G>.Fields().data
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
    
    mutating
    func update(data: @escaping (PM<ResourceList>.ResourceDTO<G, DTO.Queried>) throws -> G) {
        needsPeek = true
        updates[\PM.ResourceDTO<G, T>.resource] = { builder, _data in
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
