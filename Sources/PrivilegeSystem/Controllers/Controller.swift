import Fluent
import NIOAdvanced
import PgSQL
import Vapor
import ErrorHandle
import Policy

protocol Controller: AnyObject, Sendable {
    var db: PrivilegeSystem.PGDatabase { get }
    var eventLoop: EventLoop { get }
}

extension Controller {
    
    
    func __create<T, G, M: PGModel>(
        dtos: [T],
        label: String,
        errThrowing: PrivilegeSystem.Errcase,
        modelBuilder: @Sendable @escaping (T) -> M,
        dtoBuilder: @Sendable @escaping (M) -> Res<G, PrivilegeSystem.Errcase>
    ) -> EventLoopRes<[G], PrivilegeSystem.Errcase> {
        let models = dtos.map { modelBuilder($0) }
        
        return models
            .create(on: db)
            .withError(errThrowing, "插入\(label)失败", category: .internal)
            .flatMapThrowing
        { () throws(PrivilegeSystem.Errcase.ErrType) in
            try required(throws: errThrowing, category: .internal) {
                try models.map {
                    try dtoBuilder($0).get()
                }
            }
        }
    }
    
    func __delete<T: PGModel>(
        _ model: T.Type = T.self,
        ids: Set<T.IDValue>,
        allSatisfy: Bool = true,
        label: String,
        errThrowing: PrivilegeSystem.Errcase,
        fieldBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>,
        filterBuilder: @Sendable @escaping (QueryBuilder<T>) -> QueryBuilder<T>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        guard !ids.isEmpty else {
            return db.eventLoop.makeSucceededVoidResult()
        }
        
        return db.trans { db in
            let r: EventLoopRes<Void, PrivilegeSystem.Errcase>
            if allSatisfy {
                r = filterBuilder(fieldBuilder(T.query(on: db)))
                    .all()
                    .withError(errThrowing, "查询\(label) ID 时出错", category: .internal)
                    .flatMapThrowing
                { info throws(PrivilegeSystem.Errcase.ErrType) in
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
        errThrowing: PrivilegeSystem.Errcase,
        filterBuilder: @Sendable @escaping (QueryBuilder<T.DBModel>) -> QueryBuilder<T.DBModel>,
        dtoBuilder: @Sendable @escaping (T.DBModel) -> Res<T.QueriedDTO, PrivilegeSystem.Errcase>
    ) -> EventLoopRes<T.QueriedDTO, PrivilegeSystem.Errcase> {
        guard updater.updates.count > 0 else {
            return db.eventLoop.makeFailedResult(errThrowing.d("没有任何数据需要更新", category: .external))
        }
        
        return db.trans { db in
            let updaterRes: EventLoopRes<T.QueriedDTO?, PrivilegeSystem.Errcase>
            if updater.needsPeek {
                updaterRes = filterBuilder(T.DBModel.query(on: db))
                    .first()
                    .withError(errThrowing, "查询\(label)失败", category: .internal)
                    .flatMapThrowing { data throws(PrivilegeSystem.Errcase.ErrType) in
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
            
            return updaterRes.flatMapThrowing { userInfo throws(PrivilegeSystem.Errcase.ErrType) in
                var query = filterBuilder(T.DBModel.query(on: db))
                for builder in updater.updates.values {
                    query = try required(throws: errThrowing, "所提供的 Updater 报错", category: .external) {
                        try builder(query, userInfo)
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
            }.flatMapThrowing { data throws(PrivilegeSystem.Errcase.ErrType) in
                guard let d = data else {
                    throw errThrowing.d("Returning 时未找到修改后的\(label)", category: .internal)
                }
                return try required(throws: errThrowing, category: .internal) {
                    try dtoBuilder(d).get()
                }
            }
        }
    }
    
    func __manyToMany<Left, Right, LM, RM, TM>(
        _ relations: [MTMRelation<Left, Right>],
        action: ManyToManyAction,
        label: String,
        errThrowing: PrivilegeSystem.Errcase,
        siblingBuilder: @Sendable @escaping (Left) -> SiblingsProperty<LM, RM, TM>,
        modelsBuilder: @Sendable @escaping ([Right]) -> EventLoopRes<[RM], PrivilegeSystem.Errcase>,
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase>
        where LM: PGModel, RM: PGModel
    {
        db.trans { db in
            relations.flatMap { relation in
                relation.left.map { l in
                    modelsBuilder(relation.right).flatMap { rs in
                        let builder = siblingBuilder(l)
                        switch action {
                        case .attach:
                            return builder
                                .attach(rs, on: db)
                                .withError(errThrowing, "将\(label)关系插入中间表时失败", category: .internal)
                        case .detach:
                            return builder
                                .detach(rs, on: db)
                                .withError(errThrowing, "将\(label)关系中间表移除时失败", category: .internal)
                        }
                    }
                }
            }.flatten(on: db.eventLoop) // .flatten(on:) 会等待数组里所有的 Future 都变成成功状态，只要有一个失败，整体就会失败
        }
    }
}

enum ManyToManyAction {
    case attach
    case detach
}

func SortingSQL(uuids: [UUID]) -> String {
    let sqlArrayContent = uuids
        .map { "'\($0.uuidString)'" }
        .joined(separator: ", ")

    return "array_position(ARRAY[\(sqlArrayContent)]::uuid[], id)"
}
