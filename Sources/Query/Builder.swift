import PgSQL
import Fluent
import ErrorHandle
import NIOAdvanced

public enum Query {
    public protocol Queriable: Sendable {
        associatedtype Model: PGModel
        associatedtype ErrorType: ErrList
        static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] { get }
        static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base>
        static func make(from: Model) -> Res<Self, ErrorType>
    }
    
    public struct Builder<Model: Queriable> {
        let query: QueryBuilder<Model.Model>
        
        // Todo:
        //  all
        //  aggregate
        
        init(query: QueryBuilder<Model.Model>) {
            self.query = query
        }
        
        public func fields<Joined>(for model: Joined.Type) -> Self where Joined: Queriable {
            .init(query: Joined.buildAllFields(query))
        }
        
        public func filter<Value>(_ filter: ValueFilter<Model, Value>) -> Self {
            .init(query: query.filter(filter.filter))
        }
        
        public func join<Foreign>(
            _ foreign: Foreign.Type,
            on filter: JoinFilter<Model, Foreign>,
            method: DatabaseQuery.Join.Method = .inner
        ) -> Self {
            .init(query: query.join(Foreign.Model.self, on: filter.joinFilter, method: method))
        }
        
        public func join<Foreign>(
            _ foreign: Foreign.Type,
            on filter: JoinFilterGroup<Model, Foreign>,
            method: DatabaseQuery.Join.Method = .inner
        ) -> Self {
            .init(query: query.join(Foreign.Model.self, on: filter.wrapped, method: method))
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
            query.first()
                .withError(Errcase.fetchResultFailed, category: .internal)
                .flatMapThrowing
            { res throws(Errcase.ErrType) in
                try required(throws: Errcase.fetchResultFailed, "查询结果转为 DTO 失败", category: .internal) {
                    res == nil ? nil : try .make(from: res!).get()
                }
            }
        }
        
        public func all() -> EventLoopRes<[Model], Errcase> {
            query.all()
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
        
        public func count() -> EventLoopRes<Int, Errcase> {
            query.count()
                .withError(Errcase.countResultFailed, category: .internal)
        }
        
        public func page(with index: Int, size: Int) -> EventLoopRes<Page<Model>, Errcase> {
            query.page(withIndex: index, size: size)
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
            query.paginate(request)
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
