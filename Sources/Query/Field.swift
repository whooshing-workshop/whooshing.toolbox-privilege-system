import Fluent
import Foundation

public extension Query.Builder {
    @discardableResult
    func field<Value>(
        _ field: KeyPath<Model, Value>
    ) -> Self where Value: Codable & Sendable {
        castCodableField(field)!
    }
    
    @discardableResult
    func field<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> Self where Value: Codable & Sendable {
        castOptionalCodableField(field)!
    }
    
    @discardableResult
    func field<Value>(
        _ field: KeyPath<Model, Value>
    ) -> Self where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castEnumField(field)!
    }
    
    @discardableResult
    func field<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> Self where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castOptionalEnumField(field)!
    }
    
    @discardableResult
    func field(
        _ field: KeyPath<Model, Date>
    ) -> Self {
        castTimestampField(field)!
    }
}

public extension Query.Builder {
    @discardableResult
    func field<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) -> Self where Value: Codable & Sendable, Joined: Query.Queriable {
        castJoinedCodableField(field)!
    }
    
    @discardableResult
    func field<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) -> Self where Value: Codable & Sendable, Joined: Query.Queriable {
        castJoinedOptionalCodableField(field)!
    }
    
    @discardableResult
    func field<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) -> Self where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Joined: Query.Queriable {
        castJoinedEnumField(field)!
    }
    
    @discardableResult
    func field<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) -> Self where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Joined: Query.Queriable {
        castJoinedOptionalEnumField(field)!
    }
    
    @discardableResult
    func field<Joined>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Date>
    ) -> Self where Joined: Query.Queriable {
        castJoinedTimestampField(field)!
    }
}

extension Query.Builder {
    func castCodableField<Value>(
        _ field: KeyPath<Model, Value>
    ) -> Self? where Value: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, IDProperty<Model.Model, Value>> {
            return .init(query: query.field(field))
        } else if let field = k as? KeyPath<Model.Model, FieldProperty<Model.Model, Value>> {
            return .init(query: query.field(field))
        }
        
        return nil
    }
    
    func castOptionalCodableField<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> Self? where Value: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, FieldProperty<Model.Model, Value?>> {
            return .init(query: query.field(field))
        } else if let field = k as? KeyPath<Model.Model, OptionalFieldProperty<Model.Model, Value>> {
            return .init(query: query.field(field))
        }
        
        return nil
    }
    
    func castEnumField<Value>(
        _ field: KeyPath<Model, Value>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, EnumProperty<Model.Model, Value>> {
            return .init(query: query.field(field))
        } else if let res = castCodableField(field) {
            return res
        }
        
        return nil
    }
    
    func castOptionalEnumField<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalEnumProperty<Model.Model, Value>> {
            return .init(query: query.field(field))
        } else if let res = castOptionalCodableField(field) {
            return res
        }
        
        return nil
    }
    
    func castTimestampField(
        _ field: KeyPath<Model, Date>
    ) -> Self? {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, TimestampProperty<Model.Model, DefaultTimestampFormat>> {
            return .init(query: query.field(field))
        } else if let res = castCodableField(field) {
            return res
        }
        
        return nil
    }
}

extension Query.Builder {
    func castJoinedCodableField<M, Value>(
        _ field: KeyPath<M, Value>
    ) -> Self? where Value: Codable & Sendable, M: Query.Queriable {
        guard let k = M.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, IDProperty<M.Model, Value>> {
            return .init(query: query.field(M.Model.self, field))
        } else if let field = k as? KeyPath<M.Model, FieldProperty<M.Model, Value>> {
            return .init(query: query.field(M.Model.self, field))
        }
        
        return nil
    }
    
    func castJoinedOptionalCodableField<M, Value>(
        _ field: KeyPath<M, Value?>
    ) -> Self? where Value: Codable & Sendable, M: Query.Queriable {
        guard let k = M.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, OptionalFieldProperty<M.Model, Value>> {
            return .init(query: query.field(M.Model.self, field))
        }
        
        return nil
    }
    
    func castJoinedEnumField<M, Value>(
        _ field: KeyPath<M, Value>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, M: Query.Queriable {
        guard let k = M.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, EnumProperty<M.Model, Value>> {
            return .init(query: query.field(M.Model.self, field))
        } else if let res = castJoinedCodableField(field) {
            return res
        }
        
        return nil
    }
    
    func castJoinedOptionalEnumField<M, Value>(
        _ field: KeyPath<M, Value?>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, M: Query.Queriable {
        guard let k = M.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, OptionalEnumProperty<M.Model, Value>> {
            return .init(query: query.field(M.Model.self, field))
        } else if let res = castJoinedOptionalCodableField(field) {
            return res
        }
        
        return nil
    }
    
    func castJoinedTimestampField<M>(
        _ field: KeyPath<M, Date>
    ) -> Self? where M: Query.Queriable {
        guard let k = M.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, TimestampProperty<M.Model, DefaultTimestampFormat>> {
            return .init(query: query.field(M.Model.self, field))
        } else if let res = castJoinedCodableField(field) {
            return res
        }
        
        return nil
    }
}
