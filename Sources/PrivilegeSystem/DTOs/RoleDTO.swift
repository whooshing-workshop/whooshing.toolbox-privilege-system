import Fluent
import Foundation
import DTOBuilder
import ErrorHandle
import Collections
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable
import DataConvertable
import ResourceMacros

public struct PRole: DTO.Prepare {
    public typealias QueriedModel = QRole
    public let id: UUID?
    public let name: String
    public let summary: String?
    
    public static let logName: String = "PRole"
    
    public init(
        id: UUID? = nil,
        name: String,
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

public struct QRole: DTO.Queried {
    public typealias PrepareModel = PRole
    public let id: UUID
    public let name: String
    public let summary: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    @Sibling(
        through: UserTRole.self,
        from: \.roleId,
        to: \.userId
    )                                               public var users: [QUser]
    
    @Sibling(
        through: RoleTGroup.self,
        from: \.roleId,
        to: \.groupId
    )                                               public var groups: [QGroup]
    
    @Sibling(
        through: RoleTUserInGroup.self,
        from: \.roleId,
        to: \.userInGroupId
    )                                               public var userInGroups: [UserTGroup]
    
    @Subs(for: \.$parent)                           public var policies: [QPolicy<Role>]
    
    public static let logName: String = "QRole"
    
    package let __m: __SDBM.Role?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .name: .init(obj: self.name),
        .summary: .init(obj: self.summary),
        .createdAt: .init(obj: self.createdAt),
        .updatedAt: .init(obj: self.updatedAt),
        
        .users: .init(obj: self.$users),
        .groups: .init(obj: self.$groups),
        .userInGroups: .init(obj: self.$userInGroups),
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
        case userInGroups = "user_in_groups"
        case policies
    }
    
    init(
        id: UUID,
        name: String,
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
        self.$userInGroups.fromId = id
        self.$policies.fromId = id
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = Self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            summary: try container.decodeIfPresent(String.self, forKey: .summary),
            createdAt: try container.decode(DateWrapper.self, forKey: .createdAt).date,
            updatedAt: try container.decode(DateWrapper.self, forKey: .updatedAt).date,
            model: nil
        )
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
        try container.encode(DateWrapper(self.updatedAt), forKey: .updatedAt)
        
        try container.encode(self.$users, forKey: .users)
        try container.encode(self.$groups, forKey: .groups)
        try container.encode(self.$userInGroups, forKey: .userInGroups)
        try container.encode(self.$policies, forKey: .policies)
    }
}

extension PRole: __Prepare {
    /// 需要先存 Policy 到数据库中
    func raw() -> SQLModel {
        let role = SQLModel()
        role.id = id
        role.name = name
        role.summary = summary
        return role
    }
}

extension QRole: __Queried {
    package typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: __SDBM.Role) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .roleDTOFailed, category: .internal) {
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

extension QRole: Query.Queriable {
    public typealias Model = __SDBM.Role
    public typealias ErrorType = PrivilegeSystem.Errcase
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

public extension PRole {
    struct Updater: @unchecked Sendable {
        public let roleId: UUID
        package var id: UUID { roleId }
        
        package let updates: OrderedDictionary<
            PartialKeyPath<PRole>,
            (QueryBuilder<__SDBM.Role>, QRole?) throws -> QueryBuilder<__SDBM.Role>
        >
        package let needsPeek: Bool
        
        public init(roleId: UUID) {
            self.roleId = roleId
            self.updates = [:]
            self.needsPeek = false
        }
        
        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<PRole>,
                (QueryBuilder<__SDBM.Role>, QRole?) throws -> QueryBuilder<__SDBM.Role>
            >,
            needsPeek: Bool
        ) {
            self.roleId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension PRole.Updater: DTOUpdater {}

public extension PRole.Updater {
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

public extension PRole.Updater {
    func update(name: @escaping (QRole) throws -> String) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    func update(summary: @escaping (QRole) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.summary) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$summary, to: try summary(q))
        }
    }
}
