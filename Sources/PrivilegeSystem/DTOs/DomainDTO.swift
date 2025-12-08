import Fluent
import Foundation
import ACL
import ErrorHandle

public extension DTO {
    struct Domain<T: Status>: Sendable {
        public let ast: AST
        public let name: String?
        public let description: String?
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        init(
            _ast: AST,
            _name: String?,
            _description: String?
        ) {
            self.ast = _ast
            self.name = _name
            self.description = _description
        }
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    init(
        ast: AST,
        name: String? = nil,
        description: String? = nil
    ) {
        self = Self.init(_ast: ast, _name: name, _description: description)
    }
}

extension DTO.Domain where T == DTO.Queried {
    static func make(from model: Domain) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .domainDTOFailed, category: .internal) {
            var n = Self.init(
                _ast: model.ast,
                _name: model.name,
                _description: model.description
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updateAt = model.updatedAt
            return n
        }
    }
}

extension DTO.Domain where T == DTO.Prepare {
    func raw(domainId: UUID) -> Domain {
        let domain = Domain()
        domain.$acl.id = domainId
        domain.ast = ast
        domain.name = name
        domain.description = description
        return domain
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let domainId: UUID
        var id: UUID { domainId }
        
        private(set) var updates: [
            PartialKeyPath<DTO.Domain<DTO.Prepare>>:
            (QueryBuilder<Domain>, DTO.Domain<DTO.Queried>?) throws -> QueryBuilder<Domain>
        ] = [:]
        private(set) var needsPeek = false
        
        public init(domainId: UUID) {
            self.domainId = domainId
        }
    }
}

extension DTO.Domain.Updater: DTOUpdater {}

public extension DTO.Domain.Updater {
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

public extension DTO.Domain.Updater {
    mutating
    func update(ast: @escaping (DTO.Domain<DTO.Queried>) throws -> AST) {
        needsPeek = true
        updates[\.ast] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$ast, to: try ast(q))
        }
    }
    
    mutating
    func update(name: @escaping (DTO.Domain<DTO.Queried>) throws -> String) {
        needsPeek = true
        updates[\.name] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$name, to: try name(q))
        }
    }
    
    mutating
    func update(description: @escaping (DTO.Domain<DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.description] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}
