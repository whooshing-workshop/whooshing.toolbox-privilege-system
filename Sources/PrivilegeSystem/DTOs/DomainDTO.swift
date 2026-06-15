import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import Query
import SQLKit
import DataConvertable
import LoggingAdvanced
import AnyCodable
import ResourceMacros

package typealias DomainModel = Domain

public typealias PDomain = DTO.Domain<DTO.Prepare>
public typealias QDomain = DTO.Domain<DTO.Queried>

public extension DTO {
    struct Domain<T: Status>: DTOModel, Sendable {
        public let name: String?
        public let description: String?
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var createdAt: Date
        @Passive public internal(set) var updatedAt: Date
        
        package typealias AssociatedModel = DomainModel
        private let m: AssociatedModel?
        
        init(
            _name: String?,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    init(
        name: String? = nil,
        description: String? = nil
    ) {
        self = Self.init(_name: name, _description: description, _model: nil)
    }
}

extension DTO.Domain where T == DTO.Queried {
    var model: Domain {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: Domain) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .domainDTOFailed, category: .internal) {
            var n = Self.init(
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

extension DTO.Domain where T == DTO.Prepare {
    func raw() -> Domain {
        let domain = Domain()
        domain.name = name
        domain.description = description
        return domain
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let domainId: UUID
        package var id: UUID { domainId }
        
        package let updates: OrderedDictionary<
            PartialKeyPath<DTO.Domain<DTO.Prepare>>,
            (QueryBuilder<Domain>, DTO.Domain<DTO.Queried>?) throws -> QueryBuilder<Domain>
        >
        package let needsPeek: Bool
        
        public init(domainId: UUID) {
            self.domainId = domainId
            self.updates = [:]
            self.needsPeek = false
        }
        
        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<DTO.Domain<DTO.Prepare>>,
                (QueryBuilder<Domain>, DTO.Domain<DTO.Queried>?) throws -> QueryBuilder<Domain>
            >,
            needsPeek: Bool
        ) {
            self.domainId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension DTO.Domain.Updater: DTOUpdater {}

public extension DTO.Domain.Updater {
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

public extension DTO.Domain.Updater {
    func update(name: @escaping (DTO.Domain<DTO.Queried>) throws -> String) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }

    func update(description: @escaping (DTO.Domain<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}

extension DTO.Domain: Encodable {
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
        try container.encodeIfPresent(description, forKey: .description)
        
        if T.self != DTO.Prepare.self {
            try container.encode(id, forKey: .id)
            try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
            try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
        }
    }
}

extension DTO.Domain: Decodable where T == DTO.Prepare {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.m = nil
    }
}

extension DTO.Domain: Query.Queriable where T == DTO.Queried {
    public typealias Model = Domain
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.name: \.$name,
        \.description: \.$description,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$name)
            .field(Model.self, \.$description)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

extension DTO.Domain: Loggerable {
    public var logDescription: String {
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable]
        if T.self == DTO.Prepare.self {
            data = [
                "name": AnyCodable(self.name),
                "description": AnyCodable(self.description)
            ]
        } else {
            data = [
                "id": AnyCodable("\(self.id)"),
                "name": AnyCodable(self.name),
                "description": AnyCodable(self.description),
                "created_at": AnyCodable("\(self.createdAt)"),
                "updated_at": AnyCodable("\(self.updatedAt)")
            ]
        }

        return formatJson([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
    
    public var summaryDescription: String {
        let isQueried = T.self == DTO.Queried.self
        return isQueried ?
            name == nil ? "Domain(\(id.shortString))" : "Domain(\(id.shortString), \(name!))" :
            "Domain(\(name ?? "unsaved"))"
    }
}

extension DTO.Domain: Hashable {
    public func hash(into hasher: inout Hasher) {
        if T.self == DTO.Prepare.self {
            hasher.combine(name)
            hasher.combine(description)
        } else {
            hasher.combine(name)
            hasher.combine(description)
            hasher.combine(id)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if T.self == DTO.Prepare.self {
            lhs.name == rhs.name &&
            lhs.description == rhs.description
        } else {
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.id == rhs.id &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
        }
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    func like(_ rhs: QDomain) -> Bool {
        self.name == rhs.name &&
        self.description == rhs.description
    }
}

public extension DTO.Domain where T == DTO.Queried {
    func like(_ rhs: PDomain) -> Bool {
        self.name == rhs.name &&
        self.description == rhs.description
    }
}

public extension Collection where Element == PDomain {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == QDomain {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QDomain {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == PDomain {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}


extension DTO.Domain.Updater: Loggerable {
    public var logDescription: String {
        return formatJson([
            "target_id": AnyCodable(id.shortString),
            "updated_fields": AnyCodable(updates.keys.map { String(describing: $0) })
        ])
    }
    public var description: String { logDescription }
    public var summaryDescription: String { "DomainUpdater(\(id.shortString), updates: \(updates.keys.count))" }
}
