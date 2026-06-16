import Logging
import LoggingAdvanced
import OrderedCollections

/// 控制器 result builder 使用的一对一关系。
///
/// 使用 `=>` 运算符创建关系：
///
/// ```swift
/// let relation = role => user
/// ```
public struct OTORelation<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    /// 左侧对象。
    public let left: Left
    /// 右侧对象。
    public let right: Right
    
    /// 创建一对一关系。
    public init(left: Left, right: Right) {
        self.left = left
        self.right = right
    }
}

/// 控制器 result builder 使用的多对一关系。
///
/// ```swift
/// [policy] => role.id
/// ```
public struct MTORelation<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    /// 左侧对象集合。
    public let left: OrderedSet<Left>
    /// 右侧对象。
    public let right: Right
    
    /// 创建多对一关系。
    public init(left: OrderedSet<Left>, right: Right) {
        self.left = left
        self.right = right
    }
}

/// 控制器 result builder 使用的一对多关系。
///
/// ```swift
/// role => [userA, userB]
/// ```
public struct OTMRelation<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    /// 左侧对象。
    public let left: Left
    /// 右侧对象集合。
    public let right: OrderedSet<Right>
    
    /// 创建一对多关系。
    public init(left: Left, right: OrderedSet<Right>) {
        self.left = left
        self.right = right
    }
}

/// 控制器 result builder 使用的多对多关系。
///
/// ```swift
/// [privilege] => [AnyResource(resource)]
/// ```
public struct MTMRelation<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    /// 左侧对象集合。
    public let left: OrderedSet<Left>
    /// 右侧对象集合。
    public let right: OrderedSet<Right>
    
    /// 创建多对多关系。
    public init(left: OrderedSet<Left>, right: OrderedSet<Right>) {
        self.left = left
        self.right = right
    }
}

// MARK: - Operators

precedencegroup MappingPrecedence {
    associativity: right
    higherThan: AssignmentPrecedence
}

infix operator => : MappingPrecedence

/// 构建一对一关系。
public func => <L, R>(left: L, right: R) -> OTORelation<L, R> {
    .init(left: left, right: right)
}

/// 构建多对一关系。
public func => <L, R>(left: OrderedSet<L>, right: R) -> MTORelation<L, R> {
    .init(left: left, right: right)
}

/// 构建一对多关系。
public func => <L, R>(left: L, right: OrderedSet<R>) -> OTMRelation<L, R> {
    .init(left: left, right: right)
}

/// 构建多对多关系。
public func => <L, R>(left: OrderedSet<L>, right: OrderedSet<R>) -> MTMRelation<L, R> {
    .init(left: left, right: right)
}

// MARK: - Result Builders

@resultBuilder
public struct OTOChainRelationBuilder<Left, Right, More>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable, More: Hashable & Sendable {
    public static func buildBlock(_ components: [(Left, Right, More)]) -> OrderedSet<OTORelation<Left, OTORelation<Right, More>>> {
        .init(components.map { $0 => $1 => $2 })
    }
    
    public static func buildBlock(_ components: OrderedSet<OTORelation<Left, OTORelation<Right, More>>>) -> OrderedSet<OTORelation<Left, OTORelation<Right, More>>> {
        components
    }
    
    public static func buildBlock(_ components: OTORelation<Left, OTORelation<Right, More>>...) -> OrderedSet<OTORelation<Left, OTORelation<Right, More>>> {
        .init(components)
    }
}

@resultBuilder
public struct MTORelationBuilder<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    public static func buildBlock(_ components: [(OrderedSet<Left>, Right)]) -> OrderedSet<MTORelation<Left, Right>> {
        .init(components.map { $0 => $1 })
    }
    
    public static func buildBlock(_ components: OrderedSet<MTORelation<Left, Right>>) -> OrderedSet<MTORelation<Left, Right>> {
        components
    }
    
    public static func buildBlock(_ components: MTORelation<Left, Right>...) -> OrderedSet<MTORelation<Left, Right>> {
        .init(components)
    }
}

@resultBuilder
public struct OTMRelationBuilder<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    public static func buildBlock(_ components: [(Left, OrderedSet<Right>)]) -> OrderedSet<OTMRelation<Left, Right>> {
        .init(components.map { $0 => $1 })
    }
    
    public static func buildBlock(_ components: OrderedSet<OTMRelation<Left, Right>>) -> OrderedSet<OTMRelation<Left, Right>> {
        components
    }
    
    public static func buildBlock(_ components: OTMRelation<Left, Right>...) -> OrderedSet<OTMRelation<Left, Right>> {
        .init(components)
    }
}

@resultBuilder
public struct MTMRelationBuilder<Left, Right>: Hashable, Equatable, Sendable where Left: Hashable & Sendable, Right: Hashable & Sendable {
    public static func buildBlock(_ components: [(OrderedSet<Left>, OrderedSet<Right>)]) -> OrderedSet<MTMRelation<Left, Right>> {
        .init(components.map { $0 => $1 })
    }
    
    public static func buildBlock(_ components: OrderedSet<MTMRelation<Left, Right>>) -> OrderedSet<MTMRelation<Left, Right>> {
        components
    }
    
    public static func buildBlock(_ components: MTMRelation<Left, Right>...) -> OrderedSet<MTMRelation<Left, Right>> {
        .init(components)
    }
}

// MARK: - Loggerable Conformances
//
// 当 Left 和 Right 都实现了 Loggerable 时，Relation 类型自动获得日志能力。
// Loggerable 协议要求：
//   - logDescription: String  (完整描述，用于 debug 日志)
//   - summaryDescription: String (摘要描述，用于 info 日志)

// OTO: Left → Right
extension OTORelation: Loggerable where Left: Loggerable, Right: Loggerable {
    public var logDescription: String {
        "OTO(\(left.logDescription) → \(right.logDescription))"
    }
    public var summaryDescription: String {
        "\(left.summaryDescription) → \(right.summaryDescription)"
    }
}

// MTO: OrderedSet<Left> → Right
extension MTORelation: Loggerable where Left: Loggerable, Right: Loggerable {
    public var logDescription: String {
        let lefts = left.map { $0.logDescription }.joined(separator: ", ")
        return "MTO([\(lefts)] → \(right.logDescription))"
    }
    public var summaryDescription: String {
        let lefts = left.map { $0.summaryDescription }.joined(separator: ", ")
        return "[\(lefts)] → \(right.summaryDescription)"
    }
}

// OTM: Left → OrderedSet<Right>
extension OTMRelation: Loggerable where Left: Loggerable, Right: Loggerable {
    public var logDescription: String {
        let rights = right.map { $0.logDescription }.joined(separator: ", ")
        return "OTM(\(left.logDescription) → [\(rights)])"
    }
    public var summaryDescription: String {
        let rights = right.map { $0.summaryDescription }.joined(separator: ", ")
        return "\(left.summaryDescription) → [\(rights)]"
    }
}

// MTM: OrderedSet<Left> → OrderedSet<Right>
extension MTMRelation: Loggerable where Left: Loggerable, Right: Loggerable {
    public var logDescription: String {
        let lefts = left.map { $0.logDescription }.joined(separator: ", ")
        let rights = right.map { $0.logDescription }.joined(separator: ", ")
        return "MTM([\(lefts)] → [\(rights)])"
    }
    public var summaryDescription: String {
        let lefts = left.map { $0.summaryDescription }.joined(separator: ", ")
        let rights = right.map { $0.summaryDescription }.joined(separator: ", ")
        return "[\(lefts)] → [\(rights)]"
    }
}
