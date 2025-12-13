import Fluent
import Foundation
import ACL
import ErrorHandle

typealias DomainModel = Domain

public extension DTO {
    struct Domain<T: Status>: Sendable {
        public let expression: PrivilegeExpression
        public let name: String?
        public let description: String?
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = DomainModel
        private let m: AssociatedModel?
        
        init(
            _expression: PrivilegeExpression,
            _name: String?,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.expression = _expression
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    init(
        expression: PrivilegeExpression,
        name: String? = nil,
        description: String? = nil
    ) {
        self = Self.init(_expression: expression, _name: name, _description: description, _model: nil)
    }
}

extension DTO.Domain where T == DTO.Queried {
    var model: Domain {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: Domain) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .domainDTOFailed, category: .internal) {
            var n = Self.init(
                _expression: .init(ast: model.ast, expression: model.expression),
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

extension DTO.Domain where T == DTO.Prepare {
    func raw(domainId: UUID) -> Domain {
        let domain = Domain()
        domain.$acl.id = domainId
        domain.ast = expression.ast
        domain.expression = expression.expression
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
    func update(expression: @escaping @autoclosure () throws -> PrivilegeExpression) {
        updates[\.expression] = { builder, _ in
            let exp = try expression()
            return builder
                .set(\.$ast, to: exp.ast)
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

public extension DTO.Domain.Updater {
    mutating
    func update(expression: @escaping (DTO.Domain<DTO.Queried>) throws -> PrivilegeExpression) {
        needsPeek = true
        updates[\.expression] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            let exp = try expression(q)
            return builder
                .set(\.$ast, to: exp.ast)
                .set(\.$expression, to: exp.expression)
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
