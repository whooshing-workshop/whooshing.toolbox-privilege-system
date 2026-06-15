import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import Query
import ResourceMacros
import LoggingAdvanced
import AnyCodable
import DataConvertable

public extension PM {
    struct ResourceDTO<G: Resource>: DTOModel, Sendable where G.ResourceType == ResourceList {
        package typealias T = DTO.Queried
        
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

extension PM.ResourceDTO {
    package var model: PM<ResourceList>.ResourceModel<G> {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: PM<ResourceList>.ResourceModel<G>) -> Res<Self, S.Errcase> {
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

public extension PM.ResourceDTO {
    struct Updater: @unchecked Sendable {
        public let resourceId: UUID
        package var id: UUID { resourceId }
        
        package let updates: OrderedDictionary<
            AnyKeyPath,
            (QueryBuilder<AssociatedModel>, PM<ResourceList>.ResourceDTO<G>?) throws -> QueryBuilder<AssociatedModel>
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
                (QueryBuilder<AssociatedModel>, PM<ResourceList>.ResourceDTO<G>?) throws -> QueryBuilder<AssociatedModel>
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
    func update(data: @escaping @autoclosure () throws -> G) -> Self {
        generate(key: \PM.ResourceDTO<G>.data) { builder, _ in
            builder.set(\.$data, to: try data())
        }
    }
}

public extension PM.ResourceDTO.Updater {
    func update<V: Encodable>(path: KeyPath<G, V>, value: @escaping (PM<ResourceList>.ResourceDTO<G>) throws -> V) -> Self {
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
    
    func update(data: @escaping (PM<ResourceList>.ResourceDTO<G>) throws -> G) -> Self {
        generate(needsPeek: true, key: \PM.ResourceDTO<G>.data) { builder, _data in
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

extension PM.ResourceDTO: Encodable {
    enum CodingKeys: CodingKey {
        case data
        case id
        case createdAt
        case updatedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        if T.self != DTO.Prepare.self {
            try container.encode(id, forKey: .id)
            try container.encode(self.createdAt, forKey: .createdAt)
            try container.encode(self.updatedAt, forKey: .updatedAt)
        }
    }
}

extension PM.ResourceDTO: Query.Queriable {
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

extension PM.ResourceDTO: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
        hasher.combine(id)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data &&
        lhs.id == rhs.id &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
}

extension PM.ResourceDTO.Updater: Loggerable {
    public var logDescription: String {
        return formatJson([
            "target_id": AnyCodable(id.shortString),
            "updated_fields": AnyCodable(updates.keys.map { String(describing: $0) })
        ])
    }
    public var description: String { logDescription }
    public var summaryDescription: String { "ResourceUpdater(\(id.shortString), updates: \(updates.keys.count))" }
}

extension PM.ResourceDTO: Loggerable {
    public var logDescription: String {
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let dataMap: [String: AnyCodable]
        if T.self == DTO.Prepare.self {
            dataMap = [
                "data": AnyCodable(self.data)
            ]
        } else {
            dataMap = [
                "id": AnyCodable("\(self.id)"),
                "data": AnyCodable(self.data),
                "created_at": AnyCodable("\(self.createdAt)"),
                "updated_at": AnyCodable("\(self.updatedAt)")
            ]
        }

        return formatJson([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(dataMap)
        ])
    }
}
