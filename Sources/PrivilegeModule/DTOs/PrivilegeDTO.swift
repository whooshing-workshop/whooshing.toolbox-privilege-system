import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import Query
import DataConvertable
import LoggingAdvanced
import ResourceMacros
import AnyCodable

public extension PM {
    /// 准备写入数据库的资源权限 DTO。
    typealias PPrivilegeDTO = PrivilegeDTO<DTO.Prepare>
    /// 已从数据库查询出的资源权限 DTO。
    typealias QPrivilegeDTO = PrivilegeDTO<DTO.Queried>
    
    /// 资源权限 DTO。
    ///
    /// 每个资源权限都包含一段 OPA policy。创建后可通过
    /// `PrivilegeController.attach` 绑定到资源，并在 `Arbitrator.judge` 的
    /// `privilegeIds` 参数中参与最终鉴权。
    struct PrivilegeDTO<T: DTO.Status>: DTOModel, Sendable {
        /// 权限名称。
        public let name: String?
        /// 权限说明。
        public let description: String?
        /// OPA 策略表达式。控制器会自动包装 package、import 和默认 allow。
        public let policy: String
        
        @DTO.Passive public internal(set) var id: UUID
        @DTO.Passive public internal(set) var createdAt: Date
        @DTO.Passive public internal(set) var updatedAt: Date
        
        public typealias S = PM<ResourceList>
        package typealias AssociatedModel = Privilege
        private let m: AssociatedModel?
        
        init(
            _name: String?,
            _description: String?,
            _policy: String,
            _model: AssociatedModel?
        ) {
            self.name = _name
            self.description = _description
            self.policy = _policy
            self.m = _model
        }
    }
}

public extension PM.PrivilegeDTO where T == DTO.Prepare {
    /// 创建一个待保存的资源权限。
    ///
    /// ```swift
    /// let privilege = PM<ResourceList>.PPrivilegeDTO(
    ///     name: "ReadFile",
    ///     description: "允许读取文件",
    ///     policy: "allow if { input.operation == \"read\" }"
    /// )
    /// ```
    init(
        name: String? = nil,
        description: String? = nil,
        policy: String
    ) {
        self = Self.init(_name: name, _description: description, _policy: policy, _model: nil)
    }
}

extension PM.PrivilegeDTO where T == DTO.Queried {
    var model: PM<ResourceList>.Privilege {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: PM<ResourceList>.Privilege) -> Res<Self, S.Errcase> {
        .init(throws: .privilegeDTOFailed, category: .internal) {
            var n = Self.init(
                _name: model.name,
                _description: model.description,
                _policy: model.policy,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updatedAt = model.updatedAt
            return n
        }
    }
}

extension PM.PrivilegeDTO where T == DTO.Prepare {
    func raw() -> PM<ResourceList>.Privilege {
        let privilege = PM<ResourceList>.Privilege()
        privilege.name = name
        privilege.description = description
        privilege.policy = policy
        return privilege
    }
}

public extension PM.PrivilegeDTO where T == DTO.Prepare {
    /// 资源权限更新器。
    struct Updater: @unchecked Sendable {
        /// 要更新的资源权限 ID。
        public let privilegeId: UUID
        package var id: UUID { privilegeId }
        
        package let policyUpdate: ((PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> String)?
        
        package let updates: OrderedDictionary<
            PartialKeyPath<S.PrivilegeDTO<DTO.Prepare>>,
            (
                QueryBuilder<S.Privilege>,
                PM<ResourceList>.PrivilegeDTO<DTO.Queried>?
            ) throws -> QueryBuilder<S.Privilege>
        >
        package let needsPeek: Bool
        
        var isEmpty: Bool {
            self.updates.count == 0 && policyUpdate == nil
        }
        
        public init(privilegeId: UUID) {
            self.privilegeId = privilegeId
            self.policyUpdate = nil
            self.updates = [:]
            self.needsPeek = false
        }
        
        package init(
            id: UUID,
            policyUpdate: ((PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> String)? = nil,
            updates: OrderedDictionary<
                PartialKeyPath<S.PrivilegeDTO<DTO.Prepare>>,
                (QueryBuilder<S.Privilege>, PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> QueryBuilder<S.Privilege>
            >,
            needsPeek: Bool
        ) {
            self.privilegeId = id
            self.policyUpdate = policyUpdate
            self.updates = updates
            self.needsPeek = needsPeek
        }
        
        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<S.PrivilegeDTO<DTO.Prepare>>,
                (QueryBuilder<S.Privilege>, PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> QueryBuilder<S.Privilege>
            >,
            needsPeek: Bool
        ) {
            self.privilegeId = id
            self.policyUpdate = nil
            self.updates = updates
            self.needsPeek = needsPeek
        }
        
        package func generate(
            needsPeek: Bool = false,
            key: PartialKeyPath<S.PrivilegeDTO<DTO.Prepare>>,
            value: @escaping (QueryBuilder<S.Privilege>, PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> QueryBuilder<S.Privilege>,
            policyUpdate: ((PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> String)? = nil
        ) -> Self {
            var updates = self.updates
            updates[key] = value
            return .init(
                id: self.id,
                policyUpdate: policyUpdate ?? self.policyUpdate,
                updates: updates,
                needsPeek: self.needsPeek || needsPeek
            )
        }
    }
}

extension PM.PrivilegeDTO.Updater: DTOUpdater {}

public extension PM.PrivilegeDTO.Updater {
    /// 更新权限名称。
    func update(name: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.name) { builder, _ in
            builder.set(\.$name, to: try name())
        }
    }
    
    /// 更新权限说明。
    func update(description: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.description) { builder, _ in
            builder.set(\.$description, to: try description())
        }
    }
    
    /// 更新权限策略，并同步更新 OPA 中对应的策略内容。
    func update(policy: @escaping @autoclosure () throws -> String) -> Self {
        generate(
            key: \.policy,
            value: { builder, _ in
                builder.set(\.$policy, to: try policy())
            },
            policyUpdate: { _ in try policy() }
        )
    }
}

public extension PM.PrivilegeDTO.Updater {
    /// 基于当前数据库值更新权限名称。
    func update(name: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    /// 基于当前数据库值更新权限说明。
    func update(description: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
    
    /// 基于当前数据库值更新权限策略，并同步更新 OPA 中对应的策略内容。
    func update(policy: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String) -> Self {
        generate(
            needsPeek: true,
            key: \.policy,
            value: { builder, query in
                guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
                return builder.set(\.$policy, to: try policy(q))
            },
            policyUpdate: { query in
                guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
                return try policy(q)
            }
        )
    }
}

extension PM.PrivilegeDTO: Encodable {
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case policy
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(policy, forKey: .policy)
        
        if T.self != DTO.Prepare.self {
            try container.encode(id, forKey: .id)
            try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
            try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
        }
    }
}

extension PM.PrivilegeDTO: Decodable where T == DTO.Prepare {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.policy = try container.decode(String.self, forKey: .policy)
        self.m = nil
    }
}

extension PM.PrivilegeDTO: Query.Queriable where T == DTO.Queried {
    public typealias Model = S.Privilege
    public typealias ErrorType = S.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.name: \.$name,
        \.description: \.$description,
        \.policy: \.$policy,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$name)
            .field(Model.self, \.$description)
            .field(Model.self, \.$policy)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

extension PM.PrivilegeDTO: Hashable {
    public func hash(into hasher: inout Hasher) {
        if T.self == DTO.Prepare.self {
            hasher.combine(name)
            hasher.combine(description)
            hasher.combine(policy)
        } else {
            hasher.combine(name)
            hasher.combine(description)
            hasher.combine(policy)
            hasher.combine(id)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if T.self == DTO.Prepare.self {
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.policy == rhs.policy
        } else {
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.policy == rhs.policy &&
            lhs.id == rhs.id &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
        }
    }
}

public extension PM.PrivilegeDTO where T == DTO.Prepare {
    func like(_ rhs: PM<ResourceList>.QPrivilegeDTO) -> Bool {
        self.name == rhs.name &&
        self.description == rhs.description &&
        self.policy == rhs.policy
    }
}

public extension PM.PrivilegeDTO where T == DTO.Queried {
    func like(_ rhs: PM<ResourceList>.PPrivilegeDTO) -> Bool {
        self.name == rhs.name &&
        self.description == rhs.description &&
        self.policy == rhs.policy
    }
}

public extension Collection {
    func like<C, T>(_ rhs: C) -> Bool where C: Collection, C.Element == PM<T>.QPrivilegeDTO, Element == PM<T>.PPrivilegeDTO {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection {
    func like<C, T>(_ rhs: C) -> Bool where C: Collection, C.Element == PM<T>.PPrivilegeDTO, Element == PM<T>.QPrivilegeDTO {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

// MARK: - Loggerable

extension PM.PrivilegeDTO: Loggerable {
    public var logDescription: String {
        var parts: [String] = []
        if T.self == DTO.Prepare.self {
            if let name = name { parts.append("name:\(name)") }
            if let description = description { parts.append("description:\(description)") }
            parts.append("policy:\(policy)")
        } else {
            parts.append("id:\(id)")
            if let name = name { parts.append("name:\(name)") }
            if let description = description { parts.append("description:\(description)") }
            parts.append("policy:\(policy)")
            parts.append("createdAt:\(createdAt)")
            parts.append("updatedAt:\(updatedAt)")
        }
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        return "Privilege[\(statusLabel)](\(parts.joined(separator: ", ")))"
    }
    
    public var summaryDescription: String {
        let isQueried = T.self == DTO.Queried.self
        return isQueried ?
            name == nil ? "Privilege(\(id.shortString))" : "Privilege(\(id.shortString), \(name!))" :
            "Privilege(\(name ?? "unsaved"))"
    }
}


extension PM.PrivilegeDTO.Updater: Loggerable {
    public var logDescription: String {
        return formatJson([
            "target_id": AnyCodable(id.shortString),
            "updated_fields": AnyCodable(updates.keys.map { String(describing: $0) })
        ])
    }
    public var description: String { logDescription }
    public var summaryDescription: String { "PrivilegeUpdater(\(id.shortString), updates: \(updates.keys.count))" }
}
