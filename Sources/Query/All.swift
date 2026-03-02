import PgSQL
import Fluent
import ErrorHandle
import NIOAdvanced
import Foundation

public extension Query.Builder {
    func all() -> EventLoopRes<[Model], Query.Errcase> {
        query.all()
            .withError(Query.Errcase.fetchResultFailed, category: .internal)
            .flatMapThrowing
        { res throws(Query.Errcase.ErrType) in
            try required(throws: Query.Errcase.fetchResultFailed, "查询结果转为 DTO 失败", category: .internal) {
                try res.map {
                    try .make(from: $0).get()
                }
            }
        }
    }
}

public extension Query.Builder {
    func all<Value>(
        _ field: KeyPath<Model, Value>
    ) -> EventLoopRes<[Value], Query.Errcase> where Value: Codable & Sendable {
        castCodableAll(field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> EventLoopRes<[Value?], Query.Errcase> where Value: Codable & Sendable {
        castOptionalCodableAll(field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Value>(
        _ field: KeyPath<Model, Value>
    ) -> EventLoopRes<[Value], Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castEnumAll(field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> EventLoopRes<[Value?], Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castOptionalEnumAll(field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all(
        _ field: KeyPath<Model, Date>
    ) -> EventLoopRes<[Date], Query.Errcase> {
        castTimestampAll(field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
}

public extension Query.Builder {
    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) -> EventLoopRes<[Value], Query.Errcase> where Joined: Query.Queriable, Value: Codable & Sendable {
        castJoinedCodableAll(joined, field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) -> EventLoopRes<[Value?], Query.Errcase> where Joined: Query.Queriable, Value: Codable & Sendable {
        castJoinedOptionalCodableAll(joined, field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) -> EventLoopRes<[Value], Query.Errcase> where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castJoinedEnumAll(joined, field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) -> EventLoopRes<[Value?], Query.Errcase> where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        castJoinedOptionalEnumAll(joined, field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
    
    func all<Joined>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Date>
    ) -> EventLoopRes<[Date], Query.Errcase> where Joined: Query.Queriable {
        castJoinedTimestampAll(joined, field)!
            .withError(Query.Errcase.joinFetchResultFailed, category: .internal)
    }
}

extension Query.Builder {
    func castCodableAll<Value>(
        _ field: KeyPath<Model, Value>
    ) -> EventLoopFuture<[Value]>? where Value: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, IDProperty<Model.Model, Value>> {
            return query.all(field)
        } else if let field = k as? KeyPath<Model.Model, FieldProperty<Model.Model, Value>> {
            return query.all(field)
        }
        
        return nil
    }
    
    func castOptionalCodableAll<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> EventLoopFuture<[Value?]>? where Value: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalFieldProperty<Model.Model, Value>> {
            return query.all(field)
        }
        
        return nil
    }
    
    func castEnumAll<Value>(
        _ field: KeyPath<Model, Value>
    ) -> EventLoopFuture<[Value]>? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, EnumProperty<Model.Model, Value>> {
            return query.all(field)
        } else if let res = castCodableAll(field) {
            return res
        }
        
        return nil
    }
    
    func castOptionalEnumAll<Value>(
        _ field: KeyPath<Model, Value?>
    ) -> EventLoopFuture<[Value?]>? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalEnumProperty<Model.Model, Value>> {
            return query.all(field)
        } else if let res = castOptionalCodableAll(field) {
            return res
        }
        
        return nil
    }
    
    func castTimestampAll(
        _ field: KeyPath<Model, Date>
    ) -> EventLoopFuture<[Date]>? {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, TimestampProperty<Model.Model, DefaultTimestampFormat>> {
            return query.all(field).flatMapThrowing { dates in
                guard let res = dates as? [Date] else {
                    fatalError("时间戳永不应为 nil")
                }
                
                return res
            }
        } else if let res = castCodableAll(field) {
            return res
        }
        
        return nil
    }
}

extension Query.Builder {
    func castJoinedCodableAll<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) -> EventLoopFuture<[Value]>? where Joined: Query.Queriable, Value: Codable & Sendable {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, IDProperty<Joined.Model, Value>> {
            return query.all(Joined.Model.self, field)
        } else if let field = k as? KeyPath<Joined.Model, FieldProperty<Joined.Model, Value>> {
            return query.all(Joined.Model.self, field)
        }
        
        return nil
    }
    
    func castJoinedOptionalCodableAll<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) -> EventLoopFuture<[Value?]>? where Joined: Query.Queriable, Value: Codable & Sendable {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, OptionalFieldProperty<Joined.Model, Value>> {
            return query.all(Joined.Model.self, field)
        }
        
        return nil
    }
    
    func castJoinedEnumAll<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) -> EventLoopFuture<[Value]>? where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, EnumProperty<Joined.Model, Value>> {
            return query.all(Joined.Model.self, field)
        } else if let res = castJoinedCodableAll(joined, field) {
            return res
        }
        
        return nil
    }
    
    func castJoinedOptionalEnumAll<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) -> EventLoopFuture<[Value?]>? where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, OptionalEnumProperty<Joined.Model, Value>> {
            return query.all(Joined.Model.self, field)
        } else if let res = castJoinedOptionalCodableAll(joined, field) {
            return res
        }
        
        return nil
    }
    
    func castJoinedTimestampAll<Joined>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Date>
    ) -> EventLoopFuture<[Date]>? where Joined: Query.Queriable {
        guard let k = Joined.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Joined.Model, TimestampProperty<Joined.Model, DefaultTimestampFormat>> {
            return query.all(Joined.Model.self, field).flatMapThrowing { dates in
                guard let res = dates as? [Date] else {
                    fatalError("时间戳永不应为 nil")
                }
                
                return res
            }
        } else if let res = castJoinedCodableAll(joined, field) {
            return res
        }
        
        return nil
    }
}
