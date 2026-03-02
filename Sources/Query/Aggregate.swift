import Fluent
import NIOAdvanced
import Foundation

public extension Query.Builder {
    func count() -> EventLoopRes<Int, Query.Errcase> {
        query.count()
            .withError(Query.Errcase.aggregateResultFailed, "count 失败", category: .internal)
    }
    
    func count<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Int, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.count, key, as: Int.self)
    }
    
    func count<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Int, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.count, key, as: Int.self)
    }
    
    func count<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Int, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.count, key, as: Int.self)
    }
    
    func count<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Int, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.count, key, as: Int.self)
    }
    
    func count(_ key: KeyPath<Model, Date>) -> EventLoopRes<Int, Query.Errcase> {
        self.aggregate(.count, key, as: Int.self)
    }
}

public extension Query.Builder {
    func sum<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.sum, key)
    }
    
    func sum(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date, Query.Errcase> {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.sum, key)
    }
    
    func sum<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.sum, key)
    }
    
    func sum(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date?, Query.Errcase> {
        self.aggregate(.sum, key)
    }
}

public extension Query.Builder {
    func average<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.average, key)
    }
    
    func average(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date, Query.Errcase> {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.average, key)
    }
    
    func average<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.average, key)
    }
    
    func average(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date?, Query.Errcase> {
        self.aggregate(.average, key)
    }
}

public extension Query.Builder {
    func min<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.minimum, key)
    }
    
    func min(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date, Query.Errcase> {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.minimum, key)
    }
    
    func min<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.minimum, key)
    }
    
    func min(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date?, Query.Errcase> {
        self.aggregate(.minimum, key)
    }
}

public extension Query.Builder {
    func max<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.maximum, key)
    }
    
    func max(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date, Query.Errcase> {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.maximum, key)
    }
    
    func max<Value>(_ key: KeyPath<Model, Value?>) -> EventLoopRes<Value?, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        self.aggregate(.maximum, key)
    }
    
    func max(_ key: KeyPath<Model, Date>) -> EventLoopRes<Date?, Query.Errcase> {
        self.aggregate(.maximum, key)
    }
}

public extension Query.Builder {
    func aggregate<Result>(
        _ aggregate: DatabaseQuery.Aggregate,
        as: Result.Type = Result.self
    ) -> EventLoopRes<Result, Query.Errcase> where Result: Codable & Sendable {
        query.aggregate(aggregate)
            .withError(Query.Errcase.aggregateResultFailed, "\(aggregate) 失败", category: .internal)
    }
}

public extension Query.Builder {
    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value>,
        as result: Result.Type = Result.self
    ) -> EventLoopRes<Result, Query.Errcase> where Value: Codable & Sendable, Result: Codable & Sendable {
        castCodableAggregate(method, field, as: result)!
            .withError(Query.Errcase.aggregateResultFailed, "\(method) 失败", category: .internal)
    }
    
    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value?>,
        as result: Result.Type = Result.self
    ) -> EventLoopRes<Result, Query.Errcase> where Value: Codable & Sendable, Result: Codable & Sendable {
        castOptionalCodableAggregate(method, field, as: result)!
            .withError(Query.Errcase.aggregateResultFailed, "\(method) 失败", category: .internal)
    }
    
    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value>,
        as result: Result.Type = Result.self
    ) -> EventLoopRes<Result, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Result: Codable & Sendable {
        castEnumAggregate(method, field, as: result)!
            .withError(Query.Errcase.aggregateResultFailed, "\(method) 失败", category: .internal)
    }
    
    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value?>,
        as result: Result.Type = Result.self
    ) -> EventLoopRes<Result, Query.Errcase> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Result: Codable & Sendable {
        castOptionalEnumAggregate(method, field, as: result)!
            .withError(Query.Errcase.aggregateResultFailed, "\(method) 失败", category: .internal)
    }
    
    func aggregate<Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Date>,
        as result: Result.Type = Result.self
    ) -> EventLoopRes<Result, Query.Errcase> where Result: Codable & Sendable {
        castTimestampAggregate(method, field, as: result)!
            .withError(Query.Errcase.aggregateResultFailed, "\(method) 失败", category: .internal)
    }
}

extension Query.Builder {
    func castCodableAggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value>,
        as result: Result.Type
    ) -> EventLoopFuture<Result>? where Value: Codable & Sendable, Result: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, IDProperty<Model.Model, Value>> {
            return query.aggregate(method, field, as: result)
        } else if let field = k as? KeyPath<Model.Model, FieldProperty<Model.Model, Value>> {
            return query.aggregate(method, field, as: result)
        }
        
        return nil
    }
    
    func castOptionalCodableAggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value?>,
        as result: Result.Type
    ) -> EventLoopFuture<Result>? where Value: Codable & Sendable, Result: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalFieldProperty<Model.Model, Value>> {
            return query.aggregate(method, field, as: result)
        }
        
        return nil
    }
    
    func castEnumAggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value>,
        as result: Result.Type
    ) -> EventLoopFuture<Result>? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Result: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, EnumProperty<Model.Model, Value>> {
            return query.aggregate(method, field, as: result)
        } else if let res = castCodableAggregate(method, field, as: result) {
            return res
        }
        
        return nil
    }
    
    func castOptionalEnumAggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value?>,
        as result: Result.Type
    ) -> EventLoopFuture<Result>? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Result: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, OptionalEnumProperty<Model.Model, Value>> {
            return query.aggregate(method, field, as: result)
        } else if let res = castOptionalCodableAggregate(method, field, as: result) {
            return res
        }
        
        return nil
    }
    
    func castTimestampAggregate<Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Date>,
        as result: Result.Type
    ) -> EventLoopFuture<Result>? where Result: Codable & Sendable {
        guard let k = Model.paths[field] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<Model.Model, TimestampProperty<Model.Model, DefaultTimestampFormat>> {
            return query.aggregate(method, field, as: result)
        } else if let res = castCodableAggregate(method, field, as: result) {
            return res
        }
        
        return nil
    }
}
