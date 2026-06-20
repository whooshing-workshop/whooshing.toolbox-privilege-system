import PgSQL

public extension Query {
    struct JoinFilterGroup<L: Queriable, R: Queriable> {
        let wrapped: ComplexJoinFilterGroup
    }
}

/// `a ==/!= b && c ==/!= d`
public func && <L, R>(lhs: Query.JoinFilter<L, R>, rhs: Query.JoinFilter<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.joinFilter && rhs.joinFilter)
}

/// `a ==/!= b && c >/< 1`
public func && <L, R, Value>(lhs: Query.JoinFilter<L, R>, rhs: Query.ValueFilter<R, Value>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.joinFilter && rhs.filter)
}

/// `a ==/!= b && c >/< 1`
public func && <L, R, Value>(lhs: Query.JoinFilter<L, R>, rhs: Query.ValueFilter<L, Value>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.joinFilter && rhs.filter)
}

/// `c >/< 1 && a ==/!= b`
public func && <L, R, Value>(lhs: Query.ValueFilter<L, Value>, rhs: Query.JoinFilter<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.filter && rhs.joinFilter)
}

/// `c >/< 1 && a ==/!= b`
public func && <L, R, Value>(lhs: Query.ValueFilter<R, Value>, rhs: Query.JoinFilter<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.filter && rhs.joinFilter)
}

/// `(a == b && c != d) && e != f`
public func && <L, R>(lhs: Query.JoinFilterGroup<L, R>, rhs: Query.JoinFilter<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.wrapped && rhs.joinFilter)
}

/// `(a == b && c != d) && e < 1`
public func && <L, R, Value>(lhs: Query.JoinFilterGroup<L, R>, rhs: Query.ValueFilter<R, Value>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.wrapped && rhs.filter)
}

/// `(a == b && c != d) && e < 1`
public func && <L, R, Value>(lhs: Query.JoinFilterGroup<L, R>, rhs: Query.ValueFilter<L, Value>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.wrapped && rhs.filter)
}

/// `e != f && (a == b && c != d)`
public func && <L, R>(lhs: Query.JoinFilter<L, R>, rhs: Query.JoinFilterGroup<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.joinFilter && rhs.wrapped)
}

/// `e > 1 && (a == b && c != d)`
public func && <L, R, Value>(lhs: Query.ValueFilter<L, Value>, rhs: Query.JoinFilterGroup<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.filter && rhs.wrapped)
}

/// `e > 1 && (a == b && c != d)`
public func && <L, R, Value>(lhs: Query.ValueFilter<R, Value>, rhs: Query.JoinFilterGroup<L, R>) -> Query.JoinFilterGroup<L, R> {
    .init(wrapped: lhs.filter && rhs.wrapped)
}
