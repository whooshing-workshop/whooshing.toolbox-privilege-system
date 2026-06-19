import PgSQL
import Fluent
import ErrorHandle
import NIOAdvanced

/// `PrivilegeSystem` 和 `PrivilegeModule` 使用的类型安全查询 DSL。
///
/// `Query` 包装 Fluent 的 `QueryBuilder`，让调用方使用 DTO KeyPath 编写过滤、
/// 连接、排序、分页和聚合查询，而不必直接接触 Fluent Model KeyPath。
///
/// ```swift
/// let page = try await system.query(QUser.self)
///     .filter(\.email == "user1@example.com")
///     .sort(\.createdAt, .descending)
///     .page(with: 1, size: 20)
/// ```
public enum Query {
    public protocol System: Sendable {
        func query<T>(_ model: T.Type) -> Builder<T> where T: Queriable
    }
    
    /// 可以被查询 DSL 读取的 DTO。
    public protocol Queriable: Sendable {
        /// DTO 背后的 Fluent Model。
        associatedtype Model: PGModel
        /// Fluent 数据行转换为 DTO 时使用的错误命名空间。
        associatedtype ErrorType: ErrList
        /// DTO KeyPath 到 Fluent Model KeyPath 的映射。
        static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] { get }
        /// 添加重建该 DTO 所需的所有字段。
        static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base>
        /// 将 Fluent Model 转换为 DTO。
        static func make(from: Model) -> Res<Self, ErrorType>
        /// 构建 Builder<Self>
        static func query(on system: System) -> Builder<Self>
    }
    
    /// 可链式调用的类型化查询构建器。
    public struct Builder<Model: Queriable> {
        let query: QueryBuilder<Model.Model>
        
        package init(query: QueryBuilder<Model.Model>) {
            self.query = query
        }
        
        /// 选择 joined DTO 所需的所有字段。
        ///
        /// 当 join 查询除了基础模型字段外，还需要 joined 模型字段时调用。
        @discardableResult
        public func fields<Joined>(for model: Joined.Type) -> Self where Joined: Queriable {
            .init(query: Joined.buildAllFields(query))
        }
        
        /// 在基础 DTO 上添加过滤条件。
        @discardableResult
        public func filter<Value>(_ filter: ValueFilter<Model, Value>) -> Self {
            .init(query: query.filter(filter.filter))
        }
        
        /// 在 joined DTO 上添加过滤条件。
        @discardableResult
        public func filter<Joined, Value>(
            _ schema: Joined.Type,
            _ filter: ValueFilter<Joined, Value>
        ) -> Self where Joined: Queriable {
            .init(query: query.filter(Joined.Model.self, filter.filter))
        }
        
        /// 使用单个 join 条件连接另一个 DTO 模型。
        @discardableResult
        public func join<Foreign>(
            _ foreign: Foreign.Type,
            on filter: JoinFilter<Model, Foreign>,
            method: DatabaseQuery.Join.Method = .inner
        ) -> Self {
            .init(query: query.join(Foreign.Model.self, on: filter.joinFilter, method: method))
        }
        
        /// 使用复合 join 条件连接另一个 DTO 模型。
        @discardableResult
        public func join<Foreign>(
            _ foreign: Foreign.Type,
            on filter: JoinFilterGroup<Model, Foreign>,
            method: DatabaseQuery.Join.Method = .inner
        ) -> Self {
            .init(query: query.join(Foreign.Model.self, on: filter.wrapped, method: method))
        }
        
        /// 添加分组过滤表达式。
        ///
        /// ```swift
        /// let users = try await system.query(QUser.self)
        ///     .group(.or) { group in
        ///         group.filter(\.email == "a@example.com")
        ///         group.filter(\.email == "b@example.com")
        ///     }
        ///     .all()
        /// ```
        @discardableResult
        public func limit(_ count: Int) -> Self {
            .init(query: query.limit(count))
        }
        
        @discardableResult
        public func offset(_ count: Int) -> Self {
            .init(query: query.offset(count))
        }

        public func group(
            _ relation: DatabaseQuery.Filter.Relation = .and,
            _ closure: (Builder<Model>) throws -> ()
        ) rethrows -> Self {
            .init(query: try self.query.group(relation) { group in
                try closure(.init(query: group))
            })
        }
        
        public func first() -> EventLoopRes<Model?, Errcase> {
            query
                .first()
                .withError(Errcase.fetchResultFailed, category: .internal)
                .flatMapThrowing
            { res throws(Errcase.ErrType) in
                try required(throws: Errcase.fetchResultFailed, "查询结果转为 DTO 失败", category: .internal) {
                    res == nil ? nil : try .make(from: res!).get()
                }
            }
        }
        
        public func chunk(max: Int, closure: @escaping @Sendable ([Res<Model, Errcase>]) -> ()) -> EventLoopRes<Void, Errcase> {
            query.chunk(max: max) { res in
                closure(
                    res.map { r in
                        switch r {
                        case .success(let success):
                            do {
                                return try Res<Model, Errcase>.success(Model.make(from: success).get())
                            } catch {
                                return Res<Model, Errcase>.failure(.chunkResultFailed, "查询结果转为 DTO 失败", category: .internal, subErr: error)
                            }
                            
                        case .failure(let failure):
                            return Res<Model, Errcase>.failure(.chunkResultFailed, category: .external, subErr: failure)
                        }
                    }
                )
            }
            .withError(Errcase.chunkResultFailed, category: .internal)
        }
        
        public func page(with index: Int, size: Int) -> EventLoopRes<Page<Model>, Errcase> {
            query
                .page(withIndex: index, size: size)
                .withError(Errcase.fetchResultFailed, category: .internal)
                .flatMapThrowing
            { res throws(Errcase.ErrType) in
                try required(throws: Errcase.fetchResultFailed, "查询结果转为 DTO 失败", category: .internal) {
                    try res.map {
                        try .make(from: $0).get()
                    }
                }
            }
        }
        
        public func paginate(_ request: PageRequest) -> EventLoopRes<Page<Model>, Errcase> {
            query
                .paginate(request)
                .withError(Errcase.fetchResultFailed, category: .internal)
                .flatMapThrowing
            { res throws(Errcase.ErrType) in
                try required(throws: Errcase.fetchResultFailed, "查询结果转为 DTO 失败", category: .internal) {
                    try res.map {
                        try .make(from: $0).get()
                    }
                }
            }
        }
    }
}

public extension Query.Queriable {
    static func query(on system: Query.System) -> Query.Builder<Self> {
        system.query(Self.self)
    }
}

package protocol __QuerySystem: Query.System {
    var db: PGDatabase { get }
}
