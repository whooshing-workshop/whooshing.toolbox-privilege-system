import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import Query

public extension PM {
    struct ResourceDTO<G: Resource, T: DTO.Status>: Sendable where G.ResourceType == ResourceList {
        let data: G
        
        @DTO.Passive() public internal(set) var id: UUID
        @DTO.Passive() public internal(set) var createdAt: Date
        @DTO.Passive() public internal(set) var updatedAt: Date
        
        public typealias S = PM<ResourceList>
        package typealias AssociatedModel = ResourceModel<G>
        private let m: AssociatedModel?
        
        init(
            _data: G,
            _model: AssociatedModel?
        ) {
            self.data = _data
            self.m = _model
        }
    }
}

public extension PM.ResourceDTO where T == DTO.Prepare {
    init(
        data: G
    ) {
        self = Self.init(_data: data, _model: nil)
    }
}

extension PM.ResourceDTO where T == DTO.Queried {
    var model: PM<ResourceList>.ResourceModel<G> {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: PM<ResourceList>.ResourceModel<G>) -> Res<Self, PrivilegeModule.Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            var n = Self.init(
                _data: model.data,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updatedAt = model.updatedAt
            return n
        }
    }
}

extension PM.ResourceDTO where T == DTO.Prepare {
    func raw() -> PM<ResourceList>.ResourceModel<G> {
        .init(from: data)
    }
}

public extension PM.ResourceDTO where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let resourceId: UUID
        package var id: UUID { resourceId }
        
        package let updates: OrderedDictionary<
            AnyKeyPath,
            (QueryBuilder<AssociatedModel>, PM<ResourceList>.ResourceDTO<G, DTO.Queried>?) throws -> QueryBuilder<AssociatedModel>
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
                (QueryBuilder<AssociatedModel>, PM<ResourceList>.ResourceDTO<G, DTO.Queried>?) throws -> QueryBuilder<AssociatedModel>
            >,
            needsPeek: Bool
        ) {
            self.resourceId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension PM.ResourceDTO.Updater: DTOUpdater {}

public extension PM.ResourceDTO.Updater {
    func update<V: Encodable>(path: KeyPath<G, V>, value: @escaping @autoclosure () throws -> V) -> Self {
        generate(key: path) { builder, _ in
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
    
    func update(data: @escaping @autoclosure () throws -> G) -> Self {
        generate(key: \PM.ResourceDTO<G, T>.data) { builder, _ in
            builder.set(\.$data, to: try data())
        }
    }
}

public extension PM.ResourceDTO.Updater {
    func update<V: Encodable>(path: KeyPath<G, V>, value: @escaping (PM<ResourceList>.ResourceDTO<G, DTO.Queried>) throws -> V) -> Self {
        generate(needsPeek: true, key: path) { builder, data in
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
    
    func update(data: @escaping (PM<ResourceList>.ResourceDTO<G, DTO.Queried>) throws -> G) -> Self {
        generate(needsPeek: true, key: \PM.ResourceDTO<G, T>.data) { builder, _data in
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

extension PM.ResourceDTO: Query.Queriable where T == DTO.Queried {
    public typealias Model = S.ResourceModel<G>
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
