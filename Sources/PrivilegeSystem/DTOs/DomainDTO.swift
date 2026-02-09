import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule

typealias DomainModel = Domain

public extension DTO {
    struct Domain<T: Status>: Sendable {
        public let name: String?
        public let description: String?
        
        @Passive() public internal(set) var id: Int64
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = DomainModel
        private let m: AssociatedModel?
        
        init(
            _name: String?,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.name = _name
            self.description = _description
            self.m = _model
        }
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    init(
        name: String? = nil,
        description: String? = nil
    ) {
        self = Self.init(_name: name, _description: description, _model: nil)
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
    /// 需要先存 Policy 到数据库中
    func raw() -> Domain {
        let domain = Domain()
        domain.name = name
        domain.description = description
        return domain
    }
}

public extension DTO.Domain where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let domainId: Int64
        package var id: Int64 { domainId }
        
        package private(set) var updates: OrderedDictionary<
            PartialKeyPath<DTO.Domain<DTO.Prepare>>,
            (QueryBuilder<Domain>, DTO.Domain<DTO.Queried>?) throws -> QueryBuilder<Domain>
        > = [:]
        package private(set) var needsPeek = false
        
        public init(domainId: Int64) {
            self.domainId = domainId
        }
    }
}

extension DTO.Domain.Updater: DTOUpdater {}

public extension DTO.Domain.Updater {
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
