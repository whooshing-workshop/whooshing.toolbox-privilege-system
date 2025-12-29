import Fluent
import Foundation
import Censor
import ErrorHandle

public extension DTO {
    struct Group<T: Status>: Sendable {
        public let parentId: UUID?
        public let name: String
        public let description: String?
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = UGroup
        private let m: AssociatedModel?
        
        init(
            _parentId: UUID?,
            _name: String,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.parentId = _parentId
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Group where T == DTO.Prepare {
    init(
        parentId: UUID? = nil,
        name: String,
        description: String? = nil
    ) {
        self = Self.init(_parentId: parentId, _name: name, _description: description, _model: nil)
    }
}

extension DTO.Group where T == DTO.Queried {
    var model: UGroup {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: UGroup) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .groupDTOFailed, category: .internal) {
            var n = Self.init(
                _parentId: model.$parent.id,
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

extension DTO.Group where T == DTO.Prepare {
    func raw() -> UGroup {
        let group = UGroup()
        group.$parent.id = parentId
        group.name = name
        group.description = description
        return group
    }
}

public extension DTO.Group where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let groupId: UUID
        var id: UUID { groupId }
        
        private(set) var updates: [
            PartialKeyPath<DTO.Group<DTO.Prepare>>:
            (QueryBuilder<UGroup>, DTO.Group<DTO.Queried>?) throws -> QueryBuilder<UGroup>
        ] = [:]
        private(set) var needsPeek = false
        
        public init(groupId: UUID) {
            self.groupId = groupId
        }
    }
}

extension DTO.Group.Updater: DTOUpdater {}

public extension DTO.Group.Updater {
    mutating
    func update(parentId: @escaping @autoclosure () throws -> UUID) {
        updates[\.parentId] = { builder, _ in
            builder.set(\.$parent.$id, to: try parentId())
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

public extension DTO.Group.Updater {
    mutating
    func update(parentId: @escaping (DTO.Group<DTO.Queried>) throws -> UUID) {
        needsPeek = true
        updates[\.parentId] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$parent.$id, to: try parentId(q))
        }
    }
    
    mutating
    func update(name: @escaping (DTO.Group<DTO.Queried>) throws -> String) {
        needsPeek = true
        updates[\.name] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    mutating
    func update(description: @escaping (DTO.Group<DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.description] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}
