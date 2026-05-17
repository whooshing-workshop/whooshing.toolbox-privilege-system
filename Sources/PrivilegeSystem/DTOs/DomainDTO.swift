import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable

package typealias DomainModel = Domain

public typealias PDomain = DTO.Domain<DTO.Prepare>
public typealias QDomain = DTO.Domain<DTO.Queried>

public extension DTO {
    struct Domain<T: Status>: DTOModel, Sendable, Hashable {
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

extension DTO.Domain: Encodable where T == DTO.Queried {
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
        let isQueried = T.self == DTO.Queried.self
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? self.id : nil),
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
}

public func == (lhs: PDomain, rhs: QDomain) -> Bool {
    lhs.name == rhs.name &&
    lhs.description == rhs.description
}

public func == (lhs: QDomain, rhs: PDomain) -> Bool {
    lhs.name == rhs.name &&
    lhs.description == rhs.description
}

public func == (lhs: [PDomain], rhs: [QDomain]) -> Bool {
    lhs.elementsEqual(rhs, by: ==)
}

public func == (lhs: [QDomain], rhs: [PDomain]) -> Bool {
    lhs.elementsEqual(rhs, by: ==)
}
