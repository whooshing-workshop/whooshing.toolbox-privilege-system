import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import SQLKit
import Query
import DataConvertable
import LoggingAdvanced
import AnyCodable
import ResourceMacros

public typealias PGroup = DTO.Group<DTO.Prepare>
public typealias QGroup = DTO.Group<DTO.Queried>

public extension DTO {
    struct Group<T: Status>: DTOModel, Sendable {
        public let parentId: UUID?
        public let name: String
        public let description: String?
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var createdAt: Date
        @Passive public internal(set) var updatedAt: Date
        
        package typealias AssociatedModel = UGroup
        private let m: AssociatedModel?
        
        init(
            _parentId: UUID?,
            _name: String,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.parentId = _parentId
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Group where T == DTO.Prepare {
    init(
        under parent: DTO.Group<DTO.Queried>?,
        name: String,
        description: String? = nil
    ) {
        self = Self.init(_parentId: parent?.id, _name: name, _description: description, _model: nil)
    }
}

extension DTO.Group where T == DTO.Queried {
    var model: UGroup {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: UGroup) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .groupDTOFailed, category: .internal) {
            var n = Self.init(
                _parentId: model.$parent.id,
                _name: model.name,
                _description: model.description,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updatedAt = model.updatedAt
            return n
        }
    }
}

extension DTO.Group where T == DTO.Prepare {
    func raw() -> UGroup {
        let group = UGroup()
        group.$parent.id = parentId
        group.name = name
        group.description = description
        return group
    }
}

public extension DTO.Group where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let groupId: UUID
        package var id: UUID { groupId }
        
        package let updates: OrderedDictionary<
            PartialKeyPath<DTO.Group<DTO.Prepare>>,
            (QueryBuilder<UGroup>, DTO.Group<DTO.Queried>?) throws -> QueryBuilder<UGroup>
        >
        package let needsPeek: Bool
        
        public init(groupId: UUID) {
            self.groupId = groupId
            self.updates = [:]
            self.needsPeek = false
        }
        
        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<DTO.Group<DTO.Prepare>>,
                (QueryBuilder<UGroup>, DTO.Group<DTO.Queried>?) throws -> QueryBuilder<UGroup>
            >,
            needsPeek: Bool
        ) {
            self.groupId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension DTO.Group.Updater: DTOUpdater {}

public extension DTO.Group.Updater {
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

public extension DTO.Group.Updater {
    func update(name: @escaping (DTO.Group<DTO.Queried>) throws -> String) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    func update(description: @escaping (DTO.Group<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}

extension DTO.Group: Encodable where T == DTO.Queried {
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(id, forKey: .id)
        try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
        try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
    }
}

extension DTO.Group: Query.Queriable where T == DTO.Queried {
    public typealias Model = UGroup
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.parentId: \.$parent.$id,
        \.name: \.$name,
        \.description: \.$description,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt,
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$parent.$id)
            .field(Model.self, \.$name)
            .field(Model.self, \.$description)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

extension DTO.Group: Loggerable {
    public var logDescription: String {
        let isQueried = T.self == DTO.Queried.self
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? "\(self.id)" : nil),
            "parent_id": AnyCodable(self.parentId.map { "\($0)" }),
            "name": AnyCodable(self.name),
            "description": AnyCodable(self.description),
            "created_at": AnyCodable(isQueried ? "\(self.createdAt)" : nil),
            "updated_at": AnyCodable(isQueried ? "\(self.updatedAt)" : nil)
        ]

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
    
    public var summaryDescription: String {
        let isQueried = T.self == DTO.Queried.self
        return isQueried ?
            "Group(\(id.shortString), \(name))" :
            "Group(\(name))"
    }
}

extension DTO.Group: Hashable {
    public func hash(into hasher: inout Hasher) {
        if T.self == DTO.Prepare.self {
            hasher.combine(parentId)
            hasher.combine(name)
            hasher.combine(description)
        } else {
            hasher.combine(parentId)
            hasher.combine(name)
            hasher.combine(description)
            hasher.combine(id)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if T.self == DTO.Prepare.self {
            lhs.parentId == rhs.parentId &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description
        } else {
            lhs.parentId == rhs.parentId &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.id == rhs.id &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
        }
    }
}

public extension DTO.Group where T == DTO.Prepare {
    func like(_ rhs: QGroup) -> Bool {
        self.parentId == rhs.parentId &&
        self.name == rhs.name &&
        self.description == rhs.description
    }
}

public extension DTO.Group where T == DTO.Queried {
    func like(_ rhs: PGroup) -> Bool {
        self.parentId == rhs.parentId &&
        self.name == rhs.name &&
        self.description == rhs.description
    }
}

public extension Collection where Element == PGroup {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == QGroup {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QGroup {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == PGroup {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
