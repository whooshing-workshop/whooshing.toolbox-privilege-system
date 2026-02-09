import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule

typealias RoleModel = Role

public extension DTO {
    struct Role<T: Status>: Sendable {
        public let name: String
        public let description: String?
        
        @Passive() public internal(set) var id: Int64
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = RoleModel
        private let m: AssociatedModel?
        
        init(
            _name: String,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Role where T == DTO.Prepare {
    init(
        name: String,
        description: String?
    ) {
        self = Self.init(_name: name, _description: description, _model: nil)
    }
}

extension DTO.Role where T == DTO.Queried {
    var model: Role {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: Role) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .roleDTOFailed, category: .internal) {
            var n = Self.init(
                _name: model.name,
                _description: model.description,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updateAt = model.updatedAt
            return n
        }
    }
}

extension DTO.Role where T == DTO.Prepare {
    /// 需要先存 Policy 到数据库中
    func raw() -> Role {
        let role = Role()
        role.name = name
        role.description = description
        return role
    }
}

public extension DTO.Role where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let roleId: Int64
        package var id: Int64 { roleId }
        
        package private(set) var updates: OrderedDictionary<
            PartialKeyPath<DTO.Role<DTO.Prepare>>,
            (QueryBuilder<Role>, DTO.Role<DTO.Queried>?) throws -> QueryBuilder<Role>
        > = [:]
        package private(set) var needsPeek = false
        
        public init(roleId: Int64) {
            self.roleId = roleId
        }
    }
}

extension DTO.Role.Updater: DTOUpdater {}

public extension DTO.Role.Updater {
    mutating
    func update(name: @escaping @autoclosure () throws -> String) {
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

public extension DTO.Role.Updater {
    mutating
    func update(name: @escaping (DTO.Role<DTO.Queried>) throws -> String) {
        needsPeek = true
        updates[\.name] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    mutating
    func update(description: @escaping (DTO.Role<DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.description] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}
