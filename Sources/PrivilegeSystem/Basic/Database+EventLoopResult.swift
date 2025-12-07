import Fluent
import NIOAdvanced

extension Database {
    /// 使用自定义错误类型封装的事务执行器。
    @inlinable
    func trans<T, G>(_ closure: @escaping @Sendable (Self) -> EventLoopResult<T, G>) -> EventLoopResult<T, G> {
        self.trans { db in
            closure(db).wrapped
        }.withError()
    }
    
    /// 使用 Fluent 的事务封装异步回调。
    @inlinable
    func trans<T>(_ closure: @escaping @Sendable (Self) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.transaction { db in
            closure(db as! Self)
        }
    }
    
    /// 在 async/await 环境中执行数据库事务。
    @inlinable
    func trans<T: Sendable>(_ closure: @escaping @Sendable (Self) async throws -> T) async throws -> T {
        try await self.transaction { db in
            try await closure(db as! Self)
        }
    }
}
