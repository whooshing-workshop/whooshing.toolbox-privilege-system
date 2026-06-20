import PgSQL
import Foundation

public extension Query.ValueFilter {
    static func castArrayCodable<Values>(
        _ lhs: KeyPath<M, Value>,
        _ method: DatabaseQuery.Filter.Method,
        _ rhs: Values
    ) -> Self?
    where
        Value: Codable & Sendable,
        Values: Collection,
        Values.Element == Value
    {
        guard let k = M.paths[lhs] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, IDProperty<M.Model, Value>> {
            return .init(filter: .init(field, method, .array(rhs.map { IDProperty<M.Model, Value>.queryValue($0) })))
        } else if let field = k as? KeyPath<M.Model, FieldProperty<M.Model, Value>> {
            return .init(filter: .init(field, method, .array(rhs.map { FieldProperty<M.Model, Value>.queryValue($0) })))
        }
        
        return nil
    }
    
    static func castOptionalArrayCodable<Values>(
        _ lhs: KeyPath<M, Value?>,
        _ method: DatabaseQuery.Filter.Method,
        _ rhs: Values
    ) -> Self?
        where
            Value: Codable & Sendable,
            Values: Collection,
            Values.Element == Value
    {
        guard let k = M.paths[lhs] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, FieldProperty<M.Model, Value?>> {
            return .init(filter: .init(field, method, .array(rhs.map { FieldProperty<M.Model, Value?>.queryValue($0) })))
        } else if let field = k as? KeyPath<M.Model, OptionalFieldProperty<M.Model, Value>> {
            return .init(filter: .init(field, method, .array(rhs.map { OptionalFieldProperty<M.Model, Value>.queryValue($0) })))
        }
        
        return nil
    }
    
    static func castArrayEnum<Values>(
        _ lhs: KeyPath<M, Value>,
        _ method: DatabaseQuery.Filter.Method,
        _ rhs: Values
    ) -> Self?
        where
            Value: Codable & Sendable & RawRepresentable,
            Value.RawValue == String,
            Values: Collection,
            Values.Element == Value
    {
        guard let k = M.paths[lhs] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, EnumProperty<M.Model, Value>> {
            return .init(filter: .init(field, method, .array(rhs.map { EnumProperty<M.Model, Value>.queryValue($0) })))
        } else if let res = castArrayCodable(lhs, method, rhs) {
            return res
        }
        
        return nil
    }
    
    static func castOptionalArrayEnum<Values>(
        _ lhs: KeyPath<M, Value?>,
        _ method: DatabaseQuery.Filter.Method,
        _ rhs: Values
    ) -> Self?
        where
            Value: Codable & Sendable & RawRepresentable,
            Value.RawValue == String,
            Values: Collection,
            Values.Element == Value
    {
        guard let k = M.paths[lhs] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, OptionalEnumProperty<M.Model, Value>> {
            return .init(filter: .init(field, method, .array(rhs.map { OptionalEnumProperty<M.Model, Value>.queryValue($0) })))
        } else if let res = castOptionalArrayCodable(lhs, method, rhs) {
            return res
        }
        
        return nil
    }
    
    static func castArrayTimestamp<Values>(
        _ lhs: KeyPath<M, Value>,
        _ method: DatabaseQuery.Filter.Method,
        _ rhs: Values
    ) -> Self?
        where
            Value == Date,
            Values: Collection,
            Values.Element == Value
    {
        guard let k = M.paths[lhs] else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if let field = k as? KeyPath<M.Model, TimestampProperty<M.Model, DefaultTimestampFormat>> {
            return .init(filter: .init(field, method, .array(rhs.map { TimestampProperty<M.Model, DefaultTimestampFormat>.queryValue($0) })))
        } else if let res = castArrayCodable(lhs, method, rhs) {
            return res
        }
        
        return nil
    }
}

// MARK: -

public func ~~ <Model, Values>(lhs: KeyPath<Model, Values.Element>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable
{
    .castArrayCodable(lhs, .subset(inverse: false), rhs)!
}

public func !~ <Model, Values>(lhs: KeyPath<Model, Values.Element>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable
{
    .castArrayCodable(lhs, .subset(inverse: true), rhs)!
}

// MARK: -

public func ~~ <Model, Values>(lhs: KeyPath<Model, Values.Element?>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable
{
    .castOptionalArrayCodable(lhs, .subset(inverse: false), rhs)!
}

public func !~ <Model, Values>(lhs: KeyPath<Model, Values.Element?>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable
{
    .castOptionalArrayCodable(lhs, .subset(inverse: true), rhs)!
}

// MARK: -

public func ~~ <Model, Values>(lhs: KeyPath<Model, Values.Element>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable,
        Values.Element: Codable & Sendable & RawRepresentable,
        Values.Element.RawValue == String
{
    .castArrayEnum(lhs, .subset(inverse: false), rhs)!
}

public func !~ <Model, Values>(lhs: KeyPath<Model, Values.Element>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable,
        Values.Element: Codable & Sendable & RawRepresentable,
        Values.Element.RawValue == String
{
    .castArrayEnum(lhs, .subset(inverse: true), rhs)!
}

// MARK: -

public func ~~ <Model, Values>(lhs: KeyPath<Model, Values.Element?>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable,
        Values.Element: Codable & Sendable & RawRepresentable,
        Values.Element.RawValue == String
{
    .castOptionalArrayEnum(lhs, .subset(inverse: false), rhs)!
}

public func !~ <Model, Values>(lhs: KeyPath<Model, Values.Element?>, rhs: Values) -> Query.ValueFilter<Model, Values.Element>
    where
        Values: Collection,
        Values.Element: Codable & Sendable,
        Values.Element: Codable & Sendable & RawRepresentable,
        Values.Element.RawValue == String
{
    .castOptionalArrayEnum(lhs, .subset(inverse: true), rhs)!
}

// MARK: -

public func ~~ <Model, Values>(lhs: KeyPath<Model, Date>, rhs: Values) -> Query.ValueFilter<Model, Date>
    where
        Values: Collection,
        Values.Element == Date
{
    .castArrayTimestamp(lhs, .subset(inverse: false), rhs)!
}

public func !~ <Model, Values>(lhs: KeyPath<Model, Date>, rhs: Values) -> Query.ValueFilter<Model, Date>
    where
        Values: Collection,
        Values.Element == Date
{
    .castArrayTimestamp(lhs, .subset(inverse: true), rhs)!
}
