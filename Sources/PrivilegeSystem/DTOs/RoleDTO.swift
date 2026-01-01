import Fluent
import Foundation
import Censor
import ErrorHandle

typealias RoleModel = Role

public extension DTO {
    struct Role<T: Status>: Sendable {
        public let name: String
        public let description: String?
        public let censor: Censor<T>
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = RoleModel
        private let m: AssociatedModel?
        
        init(
            _name: String,
            _description: String?,
            _censor: Censor<T>,
            _model: AssociatedModel?
        ) {
            self.name = _name
            self.description = _description
            self.censor = _censor
            self.m = _model
        }
    }
}

public extension DTO.Role where T == DTO.Prepare {
    init(
        name: String,
        description: String?,
        censor: DTO.Censor<T>
    ) {
        self = Self.init(_name: name, _description: description, _censor: censor, _model: nil)
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
                _censor: try .make(from: model).get(),
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
        role.map = censor.map
        role.expression = censor.expression
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
    func update(censor: @escaping @autoclosure () throws -> DTO.Censor<DTO.Prepare>) {
        updates[\.censor] = { builder, _ in
            let exp = try censor()
            return builder
                .set(\.$map, to: exp.map)
                .set(\.$expression, to: exp.expression)
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
    func update(censor: @escaping (DTO.Role<DTO.Queried>) throws -> DTO.Censor<DTO.Prepare>) {
        needsPeek = true
        updates[\.censor] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            let exp = try censor(q)
            return builder
                .set(\.$map, to: exp.map)
                .set(\.$expression, to: exp.expression)
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
