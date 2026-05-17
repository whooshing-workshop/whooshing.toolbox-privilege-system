import Fluent
import Policy
import NIOAdvanced
import PgSQL
import Vapor
import ErrorHandle

package protocol Controller: AnyObject, Sendable where E.ErrType == BscError<E> {
    associatedtype E: ErrList
    var db: PGDatabase { get }
    var eventLoop: EventLoop { get }
}

package extension Controller {
    func __create<T, G, M: PGModel>(
        on db: PGDatabase,
        dtos: [T],
        label: String,
        errThrowing: E,
        modelBuilder: @Sendable @escaping (T) -> M,
        dtoBuilder: @Sendable @escaping (M) -> Res<G, E>
    ) -> EventLoopRes<[G], E> {
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
    
    func __satisfyCheck<T: PGModel>(
        on db: PGDatabase,
        _ model: T.Type = T.self,
        ids: [T.IDValue],
        allSatisfy: Bool = true,
        label: String,
        errThrowing: E,
        fieldBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>,
        filterBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>
    ) -> EventLoopRes<Void, E> {
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
        
        return r
    }
    
    func __delete<T: PGModel>(
        _ model: T.Type = T.self,
        ids: [T.IDValue],
        allSatisfy: Bool = true,
        label: String,
        errThrowing: E,
        fieldBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>,
        filterBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>
    ) -> EventLoopRes<Void, E> {
        guard !ids.isEmpty else {
            return db.eventLoop.makeSucceededVoidResult()
        }
        
        return db.trans { db in
            self.__satisfyCheck(
                on: db,
                ids: ids,
                allSatisfy: allSatisfy,
                label: label,
                errThrowing: errThrowing,
                fieldBuilder: fieldBuilder,
                filterBuilder: filterBuilder
            ).flatMap {
                filterBuilder(T.query(on: db))
                    .delete()
                    .withError(errThrowing, category: .internal)
            }
        }
    }
    
    func __update<T: DTOUpdater>(
        updater: T,
        allowEmpty: Bool = false,
        label: String,
        errThrowing: E,
        filterBuilder: @Sendable @escaping (QueryBuilder<T.DBModel>) -> QueryBuilder<T.DBModel>,
        dtoBuilder: @Sendable @escaping (T.DBModel) -> Res<T.QueriedDTO, E>
    ) -> EventLoopRes<T.QueriedDTO, E> {
        if !allowEmpty {
            guard updater.updates.count > 0 else {
                return db.eventLoop.makeFailedResult(errThrowing.d("没有任何数据需要更新", category: .external))
            }
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
                    throw errThrowing.d("\(label) 未被成功修改，Returning 未找到其改动", category: .internal)
                }
                return try required(throws: errThrowing, category: .internal) {
                    try dtoBuilder(d).get()
                }
            }
        }
    }
    
    func __manyToMany<Left, Right, PivotT>(
        _ relations: [MTMRelation<Left, Right>],
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type
    ) -> EventLoopRes<Void, E>
        where Left: DTOModel, Right: DTOModel, PivotT: PivotType,
              Left.T == DTO.Queried, Right.T == DTO.Queried,
              PivotT.PrimaryModel == Left.AssociatedModel,
              PivotT.SecondaryModel == Right.AssociatedModel
    {
        db.trans { db in
            relations.flatMap { relation in
                switch action {
                case .attach:
                    relation.left.flatMap { l in
                        relation.right.map { r in
                            let pivot = Pivot<PivotT>()
                            pivot.$primaryModel.id = l.id
                            pivot.$secondaryModel.id = r.id
                            return pivot.create(on: db)
                                .withError(errThrowing, "将 \(label) 关系插入中间表时失败", category: .internal)
                        }
                    }
                case .detach:
                    [
                        Pivot<PivotT>.query(on: db)
                            .filter(\.$primaryModel.$id ~~ relation.left.map { $0.id })
                            .filter(\.$secondaryModel.$id ~~ relation.right.map { $0.id })
                            .delete()
                            .withError(errThrowing, "将 \(label) 关系中间表移除时失败", category: .internal)
                    ]
                }
            }.flatten(on: db.eventLoop)
        }
    }
    
    func __manyToManyReversed<Left, Right, PivotT>(
        _ relations: [MTMRelation<Left, Right>],
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type
    ) -> EventLoopRes<Void, E>
        where Left: DTOModel, Right: DTOModel, PivotT: PivotType,
              Left.T == DTO.Queried, Right.T == DTO.Queried,
              PivotT.SecondaryModel == Left.AssociatedModel,
              PivotT.PrimaryModel == Right.AssociatedModel
    {
        db.trans { db in
            relations.flatMap { relation in
                switch action {
                case .attach:
                    relation.left.flatMap { l in
                        relation.right.map { r in
                            let pivot = Pivot<PivotT>()
                            pivot.$primaryModel.id = r.id
                            pivot.$secondaryModel.id = l.id
                            return pivot.create(on: db)
                                .withError(errThrowing, "将 \(label) 关系插入中间表时失败", category: .internal)
                        }
                    }
                case .detach:
                    [
                        Pivot<PivotT>.query(on: db)
                            .filter(\.$primaryModel.$id ~~ relation.right.map { $0.id })
                            .filter(\.$secondaryModel.$id ~~ relation.left.map { $0.id })
                            .delete()
                            .withError(errThrowing, "将 \(label) 关系中间表移除时失败", category: .internal)
                    ]
                }
            }.flatten(on: db.eventLoop)
        }
    }
}

package enum ManyToManyAction {
    case attach
    case detach
}

package func SortingSQL(uuids: [UUID]) -> String {
    let sqlArrayContent = uuids
        .map { "'\($0.uuidString)'" }
        .joined(separator: ", ")

    return "array_position(ARRAY[\(sqlArrayContent)]::uuid[], id)"
}
