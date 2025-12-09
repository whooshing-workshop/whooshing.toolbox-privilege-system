import Fluent
import Foundation
import ACL
import ErrorHandle

typealias RoleModel = Role

public extension DTO {
    struct Role<T: Status>: Sendable {
        public let ast: AST
        public let name: String
        public let description: String?
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = RoleModel
        private let m: AssociatedModel?
        
        init(
            _ast: AST,
            _name: String,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.ast = _ast
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Role where T == DTO.Prepare {
    init(
        ast: AST,
        name: String,
        description: String? = nil
    ) {
        self = Self.init(_ast: ast, _name: name, _description: description, _model: nil)
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
                _ast: model.ast,
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
    func raw(aclId: UUID) -> Role {
        let role = Role()
        role.$acl.id = aclId
        role.ast = ast
        role.name = name
        role.description = description
        return role
    }
}

public extension DTO.Role where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let roleId: UUID
        var id: UUID { roleId }
        
        private(set) var updates: [
            PartialKeyPath<DTO.Role<DTO.Prepare>>:
            (QueryBuilder<Role>, DTO.Role<DTO.Queried>?) throws -> QueryBuilder<Role>
        ] = [:]
        private(set) var needsPeek = false
        
        public init(roleId: UUID) {
            self.roleId = roleId
        }
    }
}

extension DTO.Role.Updater: DTOUpdater {}

public extension DTO.Role.Updater {
    mutating
    func update(ast: @escaping @autoclosure () throws -> AST) {
        updates[\.ast] = { builder, _ in
            builder.set(\.$ast, to: try ast())
        }
    }
    
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
    func update(ast: @escaping (DTO.Role<DTO.Queried>) throws -> AST) {
        needsPeek = true
        updates[\.ast] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$ast, to: try ast(q))
        }
    }
    
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
