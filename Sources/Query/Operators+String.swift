// MARK: -

public func ~= <Model>(lhs: KeyPath<Model, String>, rhs: String) -> Query.ValueFilter<Model, String> {
    .castCodable(lhs, .contains(inverse: false, .suffix), rhs)!
}

public func ~~ <Model>(lhs: KeyPath<Model, String>, rhs: String) -> Query.ValueFilter<Model, String> {
    .castCodable(lhs, .contains(inverse: false, .anywhere), rhs)!
}

public func =~ <Model>(lhs: KeyPath<Model, String>, rhs: String) -> Query.ValueFilter<Model, String> {
    .castCodable(lhs, .contains(inverse: false, .prefix), rhs)!
}

public func !~= <Model>(lhs: KeyPath<Model, String>, rhs: String) -> Query.ValueFilter<Model, String> {
    .castCodable(lhs, .contains(inverse: true, .suffix), rhs)!
}

public func !~ <Model>(lhs: KeyPath<Model, String>, rhs: String) -> Query.ValueFilter<Model, String> {
    .castCodable(lhs, .contains(inverse: true, .anywhere), rhs)!
}

public func !=~ <Model>(lhs: KeyPath<Model, String>, rhs: String) -> Query.ValueFilter<Model, String> {
    .castCodable(lhs, .contains(inverse: true, .prefix), rhs)!
}

// MARK: -

public func ~= <Model>(lhs: KeyPath<Model, String?>, rhs: String?) -> Query.ValueFilter<Model, String> {
    .castOptionalCodable(lhs, .contains(inverse: false, .suffix), rhs)!
}

public func ~~ <Model>(lhs: KeyPath<Model, String?>, rhs: String?) -> Query.ValueFilter<Model, String> {
    .castOptionalCodable(lhs, .contains(inverse: false, .anywhere), rhs)!
}

public func =~ <Model>(lhs: KeyPath<Model, String?>, rhs: String?) -> Query.ValueFilter<Model, String> {
    .castOptionalCodable(lhs, .contains(inverse: false, .prefix), rhs)!
}

public func !~= <Model>(lhs: KeyPath<Model, String?>, rhs: String?) -> Query.ValueFilter<Model, String> {
    .castOptionalCodable(lhs, .contains(inverse: true, .suffix), rhs)!
}

public func !~ <Model>(lhs: KeyPath<Model, String?>, rhs: String?) -> Query.ValueFilter<Model, String> {
    .castOptionalCodable(lhs, .contains(inverse: true, .anywhere), rhs)!
}

public func !=~ <Model>(lhs: KeyPath<Model, String?>, rhs: String?) -> Query.ValueFilter<Model, String> {
    .castOptionalCodable(lhs, .contains(inverse: true, .prefix), rhs)!
}
