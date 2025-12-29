public struct Relation<Left, Right>: Sendable where Left: Sendable, Right: Sendable {
    public let left: [Left]
    public let right: [Right]
}

precedencegroup MappingPrecedence {
    associativity: none
    higherThan: AssignmentPrecedence
}

infix operator => : MappingPrecedence

public func => <L, R>(left: L, right: R) -> Relation<L, R> {
    .init(left: [left], right: [right])
}

public func => <L, R>(left: L, right: [R]) -> Relation<L, R> {
    .init(left: [left], right: right)
}

public func => <L, R>(left: [L], right: R) -> Relation<L, R> {
    .init(left: left, right: [right])
}

public func => <L, R>(left: [L], right: [R]) -> Relation<L, R> {
    .init(left: left, right: right)
}

@resultBuilder
public struct RelationBuilder<Left, Right>: Sendable where Left: Sendable, Right: Sendable  {
    public static func buildBlock(_ components: Relation<Left, Right>...) -> [Relation<Left, Right>] {
        components
    }
}
