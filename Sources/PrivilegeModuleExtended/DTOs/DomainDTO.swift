import Foundation
import PrivilegeModule

public struct PDomain: DTO.Prepare {
    public typealias QueriedModel = QDomain
    public let id: UUID?
    public let name: String?
    public let summary: String?
    
    public static let logName: String = "QDomain"
    
    public init(
        id: UUID? = nil,
        name: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .name: .init(obj: self.name),
        .summary: .init(obj: self.summary)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.id, .name] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case name
        case summary
    }
}

public struct QDomain: DTO.Queried {
    public typealias PrepareModel = PDomain
    public let id: UUID
    public let name: String?
    public let summary: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    @Sibling(
        through: UserTDomain.self,
        from: \.domainId,
        to: \.userId
    )                                               public var users: [QUser]
    
    @Sibling(
        through: DomainTGroup.self,
        from: \.domainId,
        to: \.groupId
    )                                               public var groups: [QGroup]
    
    @Subs(for: \.$parent)                           public var policies: [QPolicy<Domain>]
    
    public static let logName: String = "QDomain"
    
    package let __m: __SDBM.Domain?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .name: .init(obj: self.name),
        .summary: .init(obj: self.summary),
        .createdAt: .init(obj: self.createdAt),
        .updatedAt: .init(obj: self.updatedAt),
        
        .users: .init(obj: self.$users),
        .groups: .init(obj: self.$groups),
        .policies: .init(obj: self.$policies)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.id, .name] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case name
        case summary
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        
        case users
        case groups
        case policies
    }
    
    init(
        id: UUID,
        name: String?,
        summary: String?,
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
        
        self.$users.fromId = id
        self.$groups.fromId = id
        self.$policies.fromId = id
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = Self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decodeIfPresent(String.self, forKey: .name),
            summary: try container.decodeIfPresent(String.self, forKey: .summary),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            model: nil
        )
        
        try self.$users.inject(from: container.nestedContainer(keyedBy: DTO.PropertyCodingKeys.self, forKey: .users))
        try self.$groups.inject(from: container.nestedContainer(keyedBy: DTO.PropertyCodingKeys.self, forKey: .groups))
        try self.$policies.inject(from: container.nestedContainer(keyedBy: DTO.PropertyCodingKeys.self, forKey: .policies))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.updatedAt, forKey: .updatedAt)
        
        try container.encode(self.$users, forKey: .users)
        try container.encode(self.$groups, forKey: .groups)
        try container.encode(self.$policies, forKey: .policies)
    }
}

extension PDomain: __Prepare {
    package func raw() -> SQLModel {
        let domain = SQLModel()
        domain.id = id
        domain.name = name
        domain.summary = summary
        return domain
    }
}

extension QDomain: __Queried {
    package typealias Failure = PrivilegeModuleExtended.Errcase
    public static func make(from model: __SDBM.Domain) -> Res<Self, PrivilegeModuleExtended.Errcase> {
        .init(throws: .domainDTOFailed, category: .internal) {
            try Self.init(
                id: model.requireID(),
                name: model.name,
                summary: model.summary,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension QDomain: Query.Queriable {
    public typealias Model = __SDBM.Domain
    public typealias ErrorType = PrivilegeModuleExtended.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        Self.idKey: \.$id,
        \.name: \.$name,
        \.summary: \.$summary,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}

    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$name)
            .field(Model.self, \.$summary)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

// MARK: - Updater

public extension PDomain {
    struct Updater: @unchecked Sendable {
        public let domainId: UUID
        package var id: UUID { domainId }

        package let updates: OrderedDictionary<
            PartialKeyPath<PDomain>,
            (QueryBuilder<__SDBM.Domain>, QDomain?) throws -> QueryBuilder<__SDBM.Domain>
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
                PartialKeyPath<PDomain>,
                (QueryBuilder<__SDBM.Domain>, QDomain?) throws -> QueryBuilder<__SDBM.Domain>
            >,
            needsPeek: Bool
        ) {
            self.domainId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension PDomain.Updater: DTOUpdater {}

public extension PDomain.Updater {
    func update(name: @escaping @autoclosure () throws -> String) -> Self {
        generate(key: \.name) { builder, _ in
            builder.set(\.$name, to: try name())
        }
    }

    func update(summary: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.summary) { builder, _ in
            builder.set(\.$summary, to: try summary())
        }
    }
}

public extension PDomain.Updater {
    func update(name: @escaping (QDomain) throws -> String) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }

    func update(summary: @escaping (QDomain) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.summary) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$summary, to: try summary(q))
        }
    }
}

public extension QDomain {
    static func testMake(
        id: UUID,
        name: String? = nil,
        summary: String? = nil,
        users: TestingRelation<[QUser], Void> = .unset(()),
        groups: TestingRelation<[QGroup], Void> = .unset(()),
        policies: TestingRelation<[QPolicy<Domain>], Void> = .unset(()),
        createdAt: Date = .init(),
        updatedAt: Date = .init()
    ) -> Self {
        let domain = QDomain(
            id: id,
            name: name,
            summary: summary,
            createdAt: createdAt,
            updatedAt: updatedAt,
            model: nil
        )
        
        domain.$users.setIfNeed(to: users)
        domain.$groups.setIfNeed(to: groups)
        domain.$policies.setIfNeed(to: policies)
        
        return domain
    }
}
