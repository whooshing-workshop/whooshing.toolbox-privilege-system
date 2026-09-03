import PgSQL
import Foundation

public struct Transactor: Sendable {
    package let db: PGDatabase
    
    package init(db: PGDatabase) {
        self.db = db
    }
    
    public func query<T>(_ model: T.Type) -> Query.Builder<T> where T: Query.Queriable {
        .init(query: T.Model.query(on: db))
    }
    
    public func atrans<T: Sendable, E>(
        throws error: E,
        _ closure: @Sendable @escaping (Self) async throws(E) -> T
    ) async throws(E) -> T {
        try await db.atrans(throws: error) { db throws(E) in
            try await closure(Transactor(db: db))
        }
    }
    
    public func atrans<T: Sendable, G: Err>(
        throws error: G.ErrorList,
        _ explain: String? = nil,
        metadata: Logger.Metadata? = nil,
        category: ErrCategory,
        file: String = #fileID,
        line: Int = #line,
        function: String = #function,
        _ closure: @escaping @Sendable (Self) async throws(G) -> T
    ) async throws(G) -> T {
        try await db.atrans(
            throws: error,
            category: category,
            file: file,
            line: line,
            function: function
        ) { db throws(G) in
            try await closure(Transactor(db: db))
        }
    }
    
    public func trans<T: Sendable, E>(
        throws error: E,
        _ closure: @Sendable @escaping (Self) -> EventLoopResult<T, E>
    ) -> EventLoopResult<T, E> {
        db.trans(throws: error) { db in
            closure(Transactor(db: db))
        }
    }
    
    public func trans<T: Sendable, G: Err>(
        throws error: G.ErrorList,
        _ explain: String? = nil,
        metadata: Logger.Metadata? = nil,
        category: ErrCategory,
        file: String = #fileID,
        line: Int = #line,
        function: String = #function,
        _ closure: @escaping @Sendable (Self) -> EventLoopResult<T, G>,
    ) -> EventLoopResult<T, G> {
        db.trans(
            throws: error,
            explain,
            category: category,
            file: file,
            line: line,
            function: function
        ) { db in
            closure(Transactor(db: db))
        }
    }
}
