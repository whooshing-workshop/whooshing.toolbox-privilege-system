import PgSQL
import Foundation

public extension Query {
    struct JoinFilter<L: Queriable, R: Queriable> {
        let joinFilter: ComplexJoinFilter

        init(joinFilter: ComplexJoinFilter) {
            self.joinFilter = joinFilter
        }
        
        // 2 x 2
        static func castCodable<Value>(
            _ left: KeyPath<L, Value>,
            _ method: DatabaseQuery.Filter.Method,
            _ right: KeyPath<R, Value>
        ) -> Self? where Value: Codable & Sendable {
            guard
                let l = L.paths[left],
                let r = R.paths[right]
            else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if
                let lField = l as? KeyPath<L.Model, IDProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, IDProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, IDProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, IDProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            }
            
            return nil
        }
        
        // 2 x 2
        static func castCodable<Value>(
            _ left: KeyPath<L, Value>,
            _ method: DatabaseQuery.Filter.Method,
            _ right: KeyPath<R, Value?>
        ) -> Self? where Value: Codable & Sendable {
            guard
                let l = L.paths[left],
                let r = R.paths[right]
            else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if
                let lField = l as? KeyPath<L.Model, IDProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value?>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value?>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, IDProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, OptionalFieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, OptionalFieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            }
            
            return nil
        }
        
        // 2 x 2
        static func castCodable<Value>(
            _ left: KeyPath<L, Value?>,
            _ method: DatabaseQuery.Filter.Method,
            _ right: KeyPath<R, Value>
        ) -> Self? where Value: Codable & Sendable {
            guard
                let l = L.paths[left],
                let r = R.paths[right]
            else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value?>>,
                let rField = r as? KeyPath<R.Model, IDProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value?>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, OptionalFieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, IDProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, OptionalFieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            }
            
            return nil
        }
        
        // 2 x 2
        static func castCodable<Value>(
            _ left: KeyPath<L, Value?>,
            _ method: DatabaseQuery.Filter.Method,
            _ right: KeyPath<R, Value?>
        ) -> Self? where Value: Codable & Sendable {
            guard
                let l = L.paths[left],
                let r = R.paths[right]
            else {
                fatalError("KeyPath 未产生正确的 Fluent 字段映射")
            }
            
            if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value?>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value?>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value?>>,
                let rField = r as? KeyPath<R.Model, OptionalFieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, OptionalFieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value?>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            } else if
                let lField = l as? KeyPath<L.Model, OptionalFieldProperty<L.Model, Value>>,
                let rField = r as? KeyPath<R.Model, OptionalFieldProperty<R.Model, Value>>
            {
                return make(lhs: lField, method: method, rhs: rField)
            }
            
            return nil
        }
    }
}

extension Query.JoinFilter {
    // 3 x 3
    static func castEnum<Value>(
        _ left: KeyPath<L, Value>,
        _ method: DatabaseQuery.Filter.Method,
        _ right: KeyPath<R, Value>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard
            let l = L.paths[left],
            let r = R.paths[right]
        else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if
            let lField = l as? KeyPath<L.Model, IDProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, EnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, EnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, IDProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, EnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, EnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, EnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, EnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if let res = castCodable(left, method, right) {
            return res
        }
        
        return nil
    }
    
    // 3 x 2
    static func castEnum<Value>(
        _ left: KeyPath<L, Value>,
        _ method: DatabaseQuery.Filter.Method,
        _ right: KeyPath<R, Value?>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard
            let l = L.paths[left],
            let r = R.paths[right]
        else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if
            let lField = l as? KeyPath<L.Model, IDProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalEnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, FieldProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalEnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, EnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalFieldProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, EnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalEnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if let res = castCodable(left, method, right) {
            return res
        }
        
        return nil
    }
    
    // 2 x 3
    static func castEnum<Value>(
        _ left: KeyPath<L, Value?>,
        _ method: DatabaseQuery.Filter.Method,
        _ right: KeyPath<R, Value>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard
            let l = L.paths[left],
            let r = R.paths[right]
        else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if
            let lField = l as? KeyPath<L.Model, OptionalEnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, IDProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, OptionalEnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, FieldProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, OptionalFieldProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, EnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, OptionalEnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, EnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if let res = castCodable(left, method, right) {
            return res
        }
        
        return nil
    }
    
    // 2 x 2
    static func castEnum<Value>(
        _ left: KeyPath<L, Value?>,
        _ method: DatabaseQuery.Filter.Method,
        _ right: KeyPath<R, Value?>
    ) -> Self? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        guard
            let l = L.paths[left],
            let r = R.paths[right]
        else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if
            let lField = l as? KeyPath<L.Model, OptionalFieldProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalEnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, OptionalEnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalFieldProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if
            let lField = l as? KeyPath<L.Model, OptionalEnumProperty<L.Model, Value>>,
            let rField = r as? KeyPath<R.Model, OptionalEnumProperty<R.Model, Value>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if let res = castCodable(left, method, right) {
            return res
        }
        
        return nil
    }
}

extension Query.JoinFilter {
    // 1 x 1
    static func castTimestamp(
        _ left: KeyPath<L, Date>,
        _ method: DatabaseQuery.Filter.Method,
        _ right: KeyPath<R, Date>
    ) -> Self? {
        guard
            let l = L.paths[left],
            let r = R.paths[right]
        else {
            fatalError("KeyPath 未产生正确的 Fluent 字段映射")
        }
        
        if
            let lField = l as? KeyPath<L.Model, TimestampProperty<L.Model, DefaultTimestampFormat>>,
            let rField = r as? KeyPath<R.Model, TimestampProperty<R.Model, DefaultTimestampFormat>>
        {
            return make(lhs: lField, method: method, rhs: rField)
        } else if let res = castCodable(left, method, right) {
            return res
        }
        
        return nil
    }
}

extension Query.JoinFilter {
    static func make<LField, RField>(
        lhs: KeyPath<L.Model, LField>,
        method: DatabaseQuery.Filter.Method,
        rhs: KeyPath<R.Model, RField>
    ) -> Self where LField: QueryableProperty, RField: QueryableProperty, LField.Value == RField.Value {
        switch method {
        case .equality(let inverse): .init(joinFilter: inverse ? (lhs != rhs) : (lhs == rhs))
        default: fatalError("暂不支持除 == 及 != 以外的 Join 查询过滤条件")
        }
    }
    
    static func make<LField, RField>(
        lhs: KeyPath<L.Model, LField>,
        method: DatabaseQuery.Filter.Method,
        rhs: KeyPath<R.Model, RField>
    ) -> Self where LField: QueryableProperty, RField: QueryableProperty, LField.Value == RField.Value? {
        switch method {
        case .equality(let inverse): .init(joinFilter: inverse ? (lhs != rhs) : (lhs == rhs))
        default: fatalError("暂不支持除 == 及 != 以外的 Join 查询过滤条件")
        }
    }
    
    static func make<LField, RField>(
        lhs: KeyPath<L.Model, LField>,
        method: DatabaseQuery.Filter.Method,
        rhs: KeyPath<R.Model, RField>
    ) -> Self where LField: QueryableProperty, RField: QueryableProperty, LField.Value? == RField.Value {
        switch method {
        case .equality(let inverse): .init(joinFilter: inverse ? (lhs != rhs) : (lhs == rhs))
        default: fatalError("暂不支持除 == 及 != 以外的 Join 查询过滤条件")
        }
    }
}

// MARK: -

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .equal, rhs)!
}

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .equal, rhs)!
}

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .equal, rhs)!
}

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .equal, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .notEqual, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .notEqual, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .notEqual, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable {
    .castCodable(lhs, .notEqual, rhs)!
}

// MARK: -

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .equal, rhs)!
}

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .equal, rhs)!
}

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .equal, rhs)!
}

public func == <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .equal, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .notEqual, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .notEqual, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .notEqual, rhs)!
}

public func != <Local, Foreign, Value>(
    lhs: KeyPath<Local, Value?>, rhs: KeyPath<Foreign, Value?>
) -> Query.JoinFilter<Local, Foreign> where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
    .castEnum(lhs, .notEqual, rhs)!
}

// MARK: -

public func == <Local, Foreign>(
    lhs: KeyPath<Local, Date>, rhs: KeyPath<Foreign, Date>
) -> Query.JoinFilter<Local, Foreign> {
    .castTimestamp(lhs, .equal, rhs)!
}

public func != <Local, Foreign>(
    lhs: KeyPath<Local, Date>, rhs: KeyPath<Foreign, Date>
) -> Query.JoinFilter<Local, Foreign> {
    .castTimestamp(lhs, .notEqual, rhs)!
}
