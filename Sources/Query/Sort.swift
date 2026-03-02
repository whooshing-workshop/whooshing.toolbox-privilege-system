import Fluent
import NIOAdvanced
import Foundation

public extension Query.Builder {
    func sort(_ sort: DatabaseQuery.Sort) -> Self {
        .init(query: query.sort(sort))
    }
}

public extension Query.Builder {
    func sort<Value>(
        _ field: KeyPath<Model, Value>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending
    ) -> Self where Value: Codable & Sendable {
        castCodableSort(field, direction)!
    }
    
    func sort<Value>(
        _ field: KeyPath<Model, Value?>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending
    ) -> Self where Value: Codable & Sendable {
        castOptionalCodableSort(field, direction)!
    }
    
    func sort<Value>(
        _ field: KeyPath<Model, Value>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending
    ) -> Self where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castEnumSort(field, direction)!
    }
    
    func sort<Value>(
        _ field: KeyPath<Model, Value?>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending
    ) -> Self where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castOptionalEnumSort(field, direction)!
    }
    
    func sort(
        _ field: KeyPath<Model, Date>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending
    ) -> Self {
        castTimestampSort(field, direction)!
    }
}

public extension Query.Builder {
    func sort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending,
        alias: String? = nil
    ) -> Self where Joined: Query.Queriable, Value: Codable & Sendable {
        castJoinedCodableSort(joined, field, direction, alias: alias)!
    }
    
    func sort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending,
        alias: String? = nil
    ) -> Self where Joined: Query.Queriable, Value: Codable & Sendable {
        castJoinedOptionalCodableSort(joined, field, direction, alias: alias)!
    }
    
    func sort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending,
        alias: String? = nil
    ) -> Self where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castJoinedEnumSort(joined, field, direction, alias: alias)!
    }
    
    func sort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending,
        alias: String? = nil
    ) -> Self where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castJoinedOptionalEnumSort(joined, field, direction, alias: alias)!
    }
    
    func sort<Joined>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Date>,
        _ direction: DatabaseQuery.Sort.Direction = .ascending,
        alias: String? = nil
    ) -> Self where Joined: Query.Queriable {
        castJoinedTimestampSort(joined, field, direction, alias: alias)!
    }
}

extension Query.Builder {
    func castCodableSort<Value>(
        _ field: KeyPath<Model, Value>,
        _ direction: DatabaseQuery.Sort.Direction
    ) -> Self? where Value: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, IDProperty<Model.Model, Value>> {
            return .init(query: query.sort(field, direction))
        } else if let field = k as? KeyPath<Model.Model, FieldProperty<Model.Model, Value>> {
            return .init(query: query.sort(field, direction))
        }
        
        return nil
    }
    
    func castOptionalCodableSort<Value>(
        _ field: KeyPath<Model, Value?>,
        _ direction: DatabaseQuery.Sort.Direction
    ) -> Self? where Value: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalFieldProperty<Model.Model, Value>> {
            return .init(query: query.sort(field, direction))
        }
        
        return nil
    }
    
    func castEnumSort<Value>(
        _ field: KeyPath<Model, Value>,
        _ direction: DatabaseQuery.Sort.Direction
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, EnumProperty<Model.Model, Value>> {
            return .init(query: query.sort(field, direction))
        } else if let res = castCodableSort(field, direction) {
            return res
        }
        
        return nil
    }
    
    func castOptionalEnumSort<Value>(
        _ field: KeyPath<Model, Value?>,
        _ direction: DatabaseQuery.Sort.Direction
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalEnumProperty<Model.Model, Value>> {
            return .init(query: query.sort(field, direction))
        } else if let res = castOptionalCodableSort(field, direction) {
            return res
        }
        
        return nil
    }
    
    func castTimestampSort(
        _ field: KeyPath<Model, Date>,
        _ direction: DatabaseQuery.Sort.Direction
    ) -> Self? {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, TimestampProperty<Model.Model, DefaultTimestampFormat>> {
            return .init(query: query.sort(field, direction))
        } else if let res = castCodableSort(field, direction) {
            return res
        }
        
        return nil
    }
}

extension Query.Builder {
    func castJoinedCodableSort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>,
        _ direction: DatabaseQuery.Sort.Direction,
        alias: String?
    ) -> Self? where Joined: Query.Queriable, Value: Codable & Sendable {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, IDProperty<Joined.Model, Value>> {
            return .init(query: query.sort(Joined.Model.self, field, alias: alias))
        } else if let field = k as? KeyPath<Model.Model, FieldProperty<Model.Model, Value>> {
            return .init(query: query.sort(field, direction))
        }
        
        return nil
    }
    
    func castJoinedOptionalCodableSort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>,
        _ direction: DatabaseQuery.Sort.Direction,
        alias: String?
    ) -> Self? where Joined: Query.Queriable, Value: Codable & Sendable {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, OptionalFieldProperty<Joined.Model, Value>> {
            return .init(query: query.sort(Joined.Model.self, field, alias: alias))
        }
        
        return nil
    }
    
    func castJoinedEnumSort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>,
        _ direction: DatabaseQuery.Sort.Direction,
        alias: String?
    ) -> Self? where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, EnumProperty<Joined.Model, Value>> {
            return .init(query: query.sort(Joined.Model.self, field, alias: alias))
        } else if let res = castJoinedCodableSort(joined, field, direction, alias: alias) {
            return res
        }
        
        return nil
    }
    
    func castJoinedOptionalEnumSort<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>,
        _ direction: DatabaseQuery.Sort.Direction,
        alias: String?
    ) -> Self? where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, OptionalEnumProperty<Joined.Model, Value>> {
            return .init(query: query.sort(Joined.Model.self, field, alias: alias))
        } else if let res = castJoinedOptionalCodableSort(joined, field, direction, alias: alias) {
            return res
        }
        
        return nil
    }
    
    func castJoinedTimestampSort<Joined>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Date>,
        _ direction: DatabaseQuery.Sort.Direction,
        alias: String?
    ) -> Self? where Joined: Query.Queriable {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, TimestampProperty<Joined.Model, DefaultTimestampFormat>> {
            return .init(query: query.sort(Joined.Model.self, field, direction, alias: alias))
        } else if let res = castJoinedCodableSort(joined, field, direction, alias: alias) {
            return res
        }
        
        return nil
    }
}
