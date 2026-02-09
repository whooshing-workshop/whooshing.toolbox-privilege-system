import Fluent
import NIOAdvanced
import PgSQL
import Vapor
import ErrorHandle

package protocol Controller: AnyObject, Sendable {
    associatedtype E: ErrList
    var db: PGDatabase { get }
    var eventLoop: EventLoop { get }
}

package extension Controller {
    func __create<T, G, M: PGModel>(
        dtos: [T],
        label: String,
        errThrowing: E,
        modelBuilder: @Sendable @escaping (T) -> M,
        dtoBuilder: @Sendable @escaping (M) -> Res<G, E>
    ) -> EventLoopRes<[G], E> where E.ErrType == BscError<E> {
        let models = dtos.map { modelBuilder($0) }
        
        return models
            .create(on: db)
            .withError(errThrowing, "插入\(label)失败", category: .internal)
            .flatMapThrowing
        { () throws(E.ErrType) in
            try required(throws: errThrowing, category: .internal) {
                try models.map {
                    try dtoBuilder($0).get()
                }
            }
        }
    }
    
    func __delete<T: PGModel>(
        _ model: T.Type = T.self,
        ids: [T.IDValue],
        allSatisfy: Bool = true,
        label: String,
        errThrowing: E,
        fieldBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>,
        filterBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>
    ) -> EventLoopRes<Void, E> where E.ErrType == BscError<E> {
        guard !ids.isEmpty else {
            return db.eventLoop.makeSucceededVoidResult()
        }
        
        return db.trans { db in
            let r: EventLoopRes<Void, E>
            if allSatisfy {
                r = filterBuilder(fieldBuilder(T.query(on: db)))
                    .all()
                    .withError(errThrowing, "查询\(label) ID 时出错", category: .internal)
                    .flatMapThrowing
                { info throws(E.ErrType) in
                    guard info.count == ids.count else {
                        throw errThrowing.d("所提供的\(label) ID 中有不存在项", category: .external)
                    }
                }
            } else {
                r = db.eventLoop.makeSucceededVoidResult()
            }
            
            return r.flatMap {
                filterBuilder(T.query(on: db))
                    .delete()
                    .withError(errThrowing, category: .internal)
            }
        }
    }
    
    func __update<T: DTOUpdater>(
        updater: T,
        label: String,
        errThrowing: E,
        filterBuilder: @Sendable @escaping (QueryBuilder<T.DBModel>) -> QueryBuilder<T.DBModel>,
        dtoBuilder: @Sendable @escaping (T.DBModel) -> Res<T.QueriedDTO, E>
    ) -> EventLoopRes<T.QueriedDTO, E> where E.ErrType == BscError<E> {
        guard updater.updates.count > 0 else {
            return db.eventLoop.makeFailedResult(errThrowing.d("没有任何数据需要更新", category: .external))
        }
        
        return db.trans { db in
            let updaterRes: EventLoopRes<T.QueriedDTO?, E>
            if updater.needsPeek {
                updaterRes = filterBuilder(T.DBModel.query(on: db))
                    .first()
                    .withError(errThrowing, "查询\(label)失败", category: .internal)
                    .flatMapThrowing { data throws(E.ErrType) in
                        guard let d = data else {
                            throw errThrowing.d("\(label)不存在", category: .external)
                        }
                        return try required(throws: errThrowing, category: .internal) {
                            try dtoBuilder(d).get()
                        }
                    }
            } else {
                updaterRes = db.eventLoop.makeSucceededResult(nil)
            }
            
            return updaterRes.flatMapThrowing { data throws(E.ErrType) in
                var query = filterBuilder(T.DBModel.query(on: db))
                for builder in updater.updates.values {
                    query = try required(throws: errThrowing, "所提供的 Updater 报错", category: .external) {
                        try builder(query, data)
                    }
                }
                return query
            }.flatMap { builder in
                builder
                    .update()
                    .withError(errThrowing, "\(label)更新时失败", category: .internal)
            }.flatMap {
                filterBuilder(T.DBModel.query(on: db))
                    .first()
                    .withError(errThrowing, "\(label) Returning 时发生错误", category: .internal)
            }.flatMapThrowing { data throws(E.ErrType) in
                guard let d = data else {
                    throw errThrowing.d("Returning 时未找到修改后的\(label)", category: .internal)
                }
                return try required(throws: errThrowing, category: .internal) {
                    try dtoBuilder(d).get()
                }
            }
        }
    }
}

protocol ModuleController: Controller where E == PrivilegeModule.Errcase {}
