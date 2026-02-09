public struct OTORelation<Left, Right>: Sendable where Left: Sendable, Right: Sendable {
    public let left: Left
    public let right: Right
    
    public init(left: Left, right: Right) {
        self.left = left
        self.right = right
    }
}

public struct MTORelation<Left, Right>: Sendable where Left: Sendable, Right: Sendable {
    public let left: [Left]
    public let right: Right
    
    public init(left: [Left], right: Right) {
        self.left = left
        self.right = right
    }
}

public struct OTMRelation<Left, Right>: Sendable where Left: Sendable, Right: Sendable {
    public let left: Left
    public let right: [Right]
    
    public init(left: Left, right: [Right]) {
        self.left = left
        self.right = right
    }
}

public struct MTMRelation<Left, Right>: Sendable where Left: Sendable, Right: Sendable {
    public let left: [Left]
    public let right: [Right]
    
    public init(left: [Left], right: [Right]) {
        self.left = left
        self.right = right
    }
}

extension OTORelation: Hashable, Equatable where Left: Hashable, Right: Hashable {}
extension MTORelation: Hashable, Equatable where Left: Hashable, Right: Hashable {}
extension OTMRelation: Hashable, Equatable where Left: Hashable, Right: Hashable {}
extension MTMRelation: Hashable, Equatable where Left: Hashable, Right: Hashable {}

precedencegroup MappingPrecedence {
    associativity: none
    higherThan: AssignmentPrecedence
}

infix operator => : MappingPrecedence

public func => <L, R>(left: L, right: R) -> OTORelation<L, R> {
    .init(left: left, right: right)
}

public func => <L, R>(left: [L], right: R) -> MTORelation<L, R> {
    .init(left: left, right: right)
}

public func => <L, R>(left: L, right: R) -> MTORelation<L, R> {
    .init(left: [left], right: right)
}

public func => <L, R>(left: L, right: [R]) -> OTMRelation<L, R> {
    .init(left: left, right: right)
}

public func => <L, R>(left: L, right: R) -> OTMRelation<L, R> {
    .init(left: left, right: [right])
}

public func => <L, R>(left: [L], right: [R]) -> MTMRelation<L, R> {
    .init(left: left, right: right)
}

public func => <L, R>(left: L, right: [R]) -> MTMRelation<L, R> {
    .init(left: [left], right: right)
}

public func => <L, R>(left: [L], right: R) -> MTMRelation<L, R> {
    .init(left: left, right: [right])
}

public func => <L, R>(left: L, right: R) -> MTMRelation<L, R> {
    .init(left: [left], right: [right])
}

@resultBuilder
public struct OTORelationBuilder<Left, Right>: Sendable where Left: Sendable, Right: Sendable  {
    public static func buildBlock(_ components: OTORelation<Left, Right>...) -> [OTORelation<Left, Right>] {
        components
    }
}

@resultBuilder
public struct MTORelationBuilder<Left, Right>: Sendable where Left: Sendable, Right: Sendable  {
    public static func buildBlock(_ components: MTORelation<Left, Right>...) -> [MTORelation<Left, Right>] {
        components
    }
}

@resultBuilder
public struct OTMRelationBuilder<Left, Right>: Sendable where Left: Sendable, Right: Sendable  {
    public static func buildBlock(_ components: OTMRelation<Left, Right>...) -> [OTMRelation<Left, Right>] {
        components
    }
}

@resultBuilder
public struct MTMRelationBuilder<Left, Right>: Sendable where Left: Sendable, Right: Sendable  {
    public static func buildBlock(_ components: MTMRelation<Left, Right>...) -> [MTMRelation<Left, Right>] {
        components
    }
}
