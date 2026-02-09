import Fluent
import Foundation
import ErrorHandle
import Collections
import SQLKit

public extension PM {
    struct PrivilegeDTO<T: DTO.Status>: Sendable {
        let name: String?
        let description: String?
        let policy: String
        
        @DTO.Passive() public internal(set) var id: Int64
        @DTO.Passive() public internal(set) var createdAt: Date
        @DTO.Passive() public internal(set) var updateAt: Date
        
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
    
    static func make(from model: PM<ResourceList>.Privilege) -> Res<Self, PM<ResourceList>.Errcase> {
        .init(throws: .resourceDTOFailed, category: .internal) {
            var n = Self.init(
                _name: model.name,
                _description: model.description,
                _policy: model.policy,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updateAt = model.updatedAt
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
        public let privilegeId: Int64
        package var id: Int64 { privilegeId }
        
        package private(set) var updates: OrderedDictionary<
            PartialKeyPath<PM<ResourceList>.PrivilegeDTO<DTO.Prepare>>,
            (
                QueryBuilder<PM<ResourceList>.Privilege>,
                PM<ResourceList>.PrivilegeDTO<DTO.Queried>?
            ) throws -> QueryBuilder<PM<ResourceList>.Privilege>
        > = [:]
        package private(set) var needsPeek = false
        
        public init(privilegeId: Int64) {
            self.privilegeId = privilegeId
        }
    }
}

extension PM.PrivilegeDTO.Updater: DTOUpdater {}

public extension PM.PrivilegeDTO.Updater {
    mutating
    func update(name: @escaping @autoclosure () throws -> String?) {
        updates[\.name] = { builder, _ in
            builder.set(\.$name, to: try name())
        }
    }
    
    mutating
    func update(description: @escaping @autoclosure () throws -> String?) {
        updates[\.description] = { builder, _ in
            builder.set(\.$description, to: try description())
        }
    }
}

public extension PM.PrivilegeDTO.Updater {
    mutating
    func update(name: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.name] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    mutating
    func update(description: @escaping (PM<ResourceList>.PrivilegeDTO<DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.description] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}
