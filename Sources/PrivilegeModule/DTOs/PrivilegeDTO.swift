import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit
import Query

public extension PM {
    struct PrivilegeDTO<T: DTO.Status>: Sendable {
        let name: String?
        let description: String?
        let policy: String
        
        @DTO.Passive() public internal(set) var id: UUID
        @DTO.Passive() public internal(set) var createdAt: Date
        @DTO.Passive() public internal(set) var updatedAt: Date
        
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
    struct Updater: @unchecked Sendable {
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
            value: @escaping (QueryBuilder<S.Privilege>, PM<ResourceList>.PrivilegeDTO<DTO.Queried>?) throws -> QueryBuilder<S.Privilege>
        ) -> Self {
            var updates = self.updates
            updates[key] = value
            return .init(
                id: self.id,
                policyUpdate: self.policyUpdate,
                updates: updates,
                needsPeek: self.needsPeek || needsPeek
            )
        }
    }
}

extension PM.PrivilegeDTO.Updater: DTOUpdater {}

public extension PM.PrivilegeDTO.Updater {
    func update(name: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.name) { builder, _ in
            builder.set(\.$name, to: try name())
        }
    }
    
    func update(description: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.description) { builder, _ in
            builder.set(\.$description, to: try description())
        }
    }
    
    func update(policy: @escaping @autoclosure () throws -> String) -> Self {
        .init(
            id: self.id,
            policyUpdate: { _ in try policy() },
            updates: self.updates,
            needsPeek: self.needsPeek
        )
    }
}

public extension PM.PrivilegeDTO.Updater {
    func update(name: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.name) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    func update(description: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
    
    func update(policy: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String) -> Self {
        .init(
            id: self.id,
            policyUpdate: { query in
                guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
                return try policy(q)
            },
            updates: self.updates,
            needsPeek: true
        )
    }
}

extension PM.PrivilegeDTO: Encodable where T == DTO.Queried {
    enum CodingKeys: CodingKey {
        case name
        case description
        case policy
        case id
        case createdAt
        case updatedAt
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
