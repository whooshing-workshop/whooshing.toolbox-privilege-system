import PgSQL
import Foundation

public extension Query {
    internal protocol FilterProvider {
        associatedtype Model: PGModel
        var filter: ModelValueFilter<Model> { get }
    }

    struct ValueFilter<M: Queriable, Value>: FilterProvider {
        let filter: ModelValueFilter<M.Model>
        
        init(filter: ModelValueFilter<M.Model>) {
            self.filter = filter
        }

        static func castCodable(
            _ lhs: KeyPath<M, Value>,
            _ method: DatabaseQuery.Filter.Method,
            _ rhs: Value
        ) -> Self? where Value: Codable & Sendable {
            guard let k = M.paths[lhs] else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if let field = k as? KeyPath<M.Model, IDProperty<M.Model, Value>> {
                return .init(filter: .init(field, method, .bind(rhs)))
            } else if let field = k as? KeyPath<M.Model, FieldProperty<M.Model, Value>> {
                return .init(filter: .init(field, method, .bind(rhs)))
            }
            
            return nil
        }
        
        static func castOptionalCodable(
            _ lhs: KeyPath<M, Value?>,
            _ method: DatabaseQuery.Filter.Method,
            _ rhs: Value?
        ) -> Self? where Value: Codable & Sendable {
            guard let k = M.paths[lhs] else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if let field = k as? KeyPath<M.Model, IDProperty<M.Model, Value>> {
                return .init(filter: .init(field, method, rhs == nil ? .null : .bind(rhs!)))
            } else if let field = k as? KeyPath<M.Model, FieldProperty<M.Model, Value?>> {
                return .init(filter: .init(field, method, .bind(rhs)))
            } else if let field = k as? KeyPath<M.Model, OptionalFieldProperty<M.Model, Value>> {
                return .init(filter: .init(field, method, rhs == nil ? .null : .bind(rhs!)))
            }
            
            return nil
        }
        
        static func castEnum(
            _ lhs: KeyPath<M, Value>,
            _ method: DatabaseQuery.Filter.Method,
            _ rhs: Value
        ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
            guard let k = M.paths[lhs] else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if let field = k as? KeyPath<M.Model, EnumProperty<M.Model, Value>> {
                return .init(filter: .init(field, method, .enumCase(rhs.rawValue)))
            } else if let res = castCodable(lhs, method, rhs) {
                return res
            }
            
            return nil
        }
        
        static func castOptionalEnum(
            _ lhs: KeyPath<M, Value?>,
            _ method: DatabaseQuery.Filter.Method,
            _ rhs: Value?
        ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
            guard let k = M.paths[lhs] else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if let field = k as? KeyPath<M.Model, OptionalEnumProperty<M.Model, Value>> {
                return .init(filter: .init(field, method, rhs == nil ? .null : .enumCase(rhs!.rawValue)))
            } else if let res = castOptionalCodable(lhs, method, rhs) {
                return res
            }
            
            return nil
        }
        
        static func castTimestamp(
            _ lhs: KeyPath<M, Value>,
            _ method: DatabaseQuery.Filter.Method,
            _ rhs: Value
        ) -> Self? where Value == Date {
            guard let k = M.paths[lhs] else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if let field = k as? KeyPath<M.Model, TimestampProperty<M.Model, DefaultTimestampFormat>> {
                return .init(filter: .init(field, method, .bind(rhs)))
            } else if let res = castCodable(lhs, method, rhs) {
                return res
            }
            
            return nil
        }
    }
}

// MARK: -

public func == <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castCodable(lhs, .equal, rhs)!
}

public func != <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castCodable(lhs, .notEqual, rhs)!
}

public func >= <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castCodable(lhs, .greaterThanOrEqual, rhs)!
}

public func > <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castCodable(lhs, .greaterThan, rhs)!
}

public func < <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castCodable(lhs, .lessThan, rhs)!
}

public func <= <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castCodable(lhs, .lessThanOrEqual, rhs)!
}

// MARK: -

public func == <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castOptionalCodable(lhs, .equal, rhs)!
}

public func != <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castOptionalCodable(lhs, .notEqual, rhs)!
}

public func >= <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castOptionalCodable(lhs, .greaterThanOrEqual, rhs)!
}

public func > <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castOptionalCodable(lhs, .greaterThan, rhs)!
}

public func < <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castOptionalCodable(lhs, .lessThan, rhs)!
}

public func <= <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable {
    .castOptionalCodable(lhs, .lessThanOrEqual, rhs)!
}

// MARK: -

public func == <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .equal, rhs)!
}

public func != <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .notEqual, rhs)!
}

public func >= <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .greaterThanOrEqual, rhs)!
}

public func > <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .greaterThan, rhs)!
}

public func < <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .lessThan, rhs)!
}

public func <= <Model, Value>(lhs: KeyPath<Model, Value>, rhs: Value) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .lessThanOrEqual, rhs)!
}

// MARK: -

public func == <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castOptionalEnum(lhs, .equal, rhs)!
}

public func != <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castOptionalEnum(lhs, .notEqual, rhs)!
}

public func >= <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castOptionalEnum(lhs, .greaterThanOrEqual, rhs)!
}

public func > <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castOptionalEnum(lhs, .greaterThan, rhs)!
}

public func < <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castOptionalEnum(lhs, .lessThan, rhs)!
}

public func <= <Model, Value>(lhs: KeyPath<Model, Value?>, rhs: Value?) -> Query.ValueFilter<Model, Value> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castOptionalEnum(lhs, .lessThanOrEqual, rhs)!
}

// MARK: -

public func == <Model>(lhs: KeyPath<Model, Date>, rhs: Date) -> Query.ValueFilter<Model, Date> {
    .castTimestamp(lhs, .equal, rhs)!
}

public func != <Model>(lhs: KeyPath<Model, Date>, rhs: Date) -> Query.ValueFilter<Model, Date> {
    .castTimestamp(lhs, .notEqual, rhs)!
}

public func >= <Model>(lhs: KeyPath<Model, Date>, rhs: Date) -> Query.ValueFilter<Model, Date> {
    .castTimestamp(lhs, .greaterThanOrEqual, rhs)!
}

public func > <Model>(lhs: KeyPath<Model, Date>, rhs: Date) -> Query.ValueFilter<Model, Date> {
    .castTimestamp(lhs, .greaterThan, rhs)!
}

public func < <Model>(lhs: KeyPath<Model, Date>, rhs: Date) -> Query.ValueFilter<Model, Date> {
    .castTimestamp(lhs, .lessThan, rhs)!
}

public func <= <Model>(lhs: KeyPath<Model, Date>, rhs: Date) -> Query.ValueFilter<Model, Date> {
    .castTimestamp(lhs, .lessThanOrEqual, rhs)!
}
