import DTOBuilder
import Fluent
import Foundation
import NIOHTTP1

package protocol Controller: AnyObject, Sendable where E.ErrType == BasicError<E> {
    associatedtype E: ErrList
    var db: PGDatabase { get }
    var eventLoop: EventLoop { get }
    var logger: Logger { get }
}

package extension Controller {
    func getActionLogger() -> Logger {
        self.logger.derive(metadata: ["action-id": .stringConvertible(UUID())])
    }
    
    func __create<T, G, M: PGModel, A: Error>(
        on db: PGDatabase,
        dtos: OrderedSet<T>,
        label: String,
        errThrowing: E,
        modelBuilder: @Sendable @escaping (T) -> Res<M, E>,
        dtoBuilder: @Sendable @escaping (M) -> Result<G, A>
    ) -> EventLoopRes<[G], E> {
        do {
            let models = try dtos.map { try modelBuilder($0).get() }
            
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
        } catch let error {
            return db.eventLoop.makeFailedResult(error as! BasicError<E>)
        }
    }
    
    // 提供 ids 进行数据库检查，如果有 id 不存在，则会返回不存在的 id
    // 若均存在，则返回空数组
    func __check<Model: __Model>(
        on db: PGDatabase,
        ids: OrderedSet<UUID>,
        for: Model.Type,
        label: String,
        errThrowing: E
    ) -> EventLoopRes<OrderedSet<UUID>, E> {
        let ids = Set(ids)
        return Model.SQLModel.query(on: db)
            .field(Model.idProperty)
            .filter(Model.idProperty ~~ ids)
            .all()
            .withError(errThrowing, "\(label) 按 id 检查记录失败", category: .internal)
            .flatMapThrowing
        { models throws(E.ErrType) in
            try required(throws: errThrowing, "\(label) 从查询结果取得模型 Id 失败", category: .internal) {
                try Set(
                    models.map { model in
                        try model.requireID()
                    }
                )
            }
        }.flatMap { resIds in
            if resIds.count == ids.count {
                return db.eventLoop.makeSucceededResult([])
            }
            let diffs = OrderedSet<UUID>(ids.subtracting(resIds))
            return db.eventLoop.makeSucceededResult(diffs)
        }
    }
    
    func __delete<T: __Model>(
        on db: PGDatabase,
        _ model: T.Type = T.self,
        ids: OrderedSet<UUID>,
        allSatisfy: Bool = true,
        label: String,
        errThrowing: E,
        fieldBuilder: @Sendable @escaping (QueryBuilder<T.SQLModel>) -> QueryBuilder<T.SQLModel>,
        filterBuilder: @Sendable @escaping (QueryBuilder<T.SQLModel>) -> QueryBuilder<T.SQLModel>
    ) -> EventLoopRes<Void, E> {
        guard !ids.isEmpty else {
            return db.eventLoop.makeSucceededVoidResult()
        }
        
        return db.trans(throws: errThrowing, "数据库事务执行失败", category: .internal) { db in
            let r: EventLoopRes<Void, E>
            
            if allSatisfy {
                r = self.__check(
                    on: db,
                    ids: ids,
                    for: model,
                    label: label,
                    errThrowing: errThrowing
                ).flatMap { diffs in
                    guard diffs.count == 0 else {
                        return db.eventLoop.makeFailedResult(errThrowing, "\(label) 记录删除失败，预期记录未在数据库中找到", metadata: ["invalid": .data(diffs)], category: .inherit)
                    }
                    
                    return db.eventLoop.makeSucceededVoidResult()
                }
            } else {
                r = db.eventLoop.makeSucceededVoidResult()
            }
            
            return r.flatMap {
                filterBuilder(T.SQLModel.query(on: db))
                    .delete()
                    .withError(errThrowing, "根据 \(label) id 从数据库删除记录失败", category: .internal)
            }
        }
    }
    
    func __update<T: DTOUpdater, A: Error>(
        on db: PGDatabase,
        updater: T,
        label: String,
        errThrowing: E,
        filterBuilder: @Sendable @escaping (QueryBuilder<T.DBModel>) -> QueryBuilder<T.DBModel>,
        dtoBuilder: @Sendable @escaping (T.DBModel) -> Result<T.QueriedDTO, A>
    ) -> EventLoopRes<T.QueriedDTO, E> {
        guard updater.updates.count > 0 else {
            return db.eventLoop.makeFailedResult(errThrowing.d("没有任何数据需要更新", category: .external(userdata: .init(HTTPResponseStatus.unprocessableEntity))))
        }
        
        return db.trans(throws: errThrowing, "数据库事务执行失败", category: .internal) { db in
            let updaterRes: EventLoopRes<T.QueriedDTO?, E>
            if updater.needsPeek {
                updaterRes = filterBuilder(T.DBModel.query(on: db))
                    .first()
                    .withError(errThrowing, "查询\(label)失败", category: .internal)
                    .flatMapThrowing
                { data throws(E.ErrType) in
                    guard let d = data else {
                        throw errThrowing.d("\(label)不存在", category: .external(userdata: .init(HTTPResponseStatus.notFound)))
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
                    query = try required(throws: errThrowing, "所提供的 Updater 出错", category: .external(userdata: .init(HTTPResponseStatus.badRequest))) {
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
    
    // MARK: - Many to Many
    
    func __manyToMany<Left, Right, PivotT>(
        on db: PGDatabase,
        _ relations: OrderedSet<MTMRelation<Left, Right>>,
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type
    ) -> EventLoopRes<Void, E>
        where Left: __Model, Right: __Model, PivotT: PivotType,
              PivotT.PrimaryModel == Left.SQLModel,
              PivotT.SecondaryModel == Right.SQLModel
    {
        var idRelations: OrderedSet<MTMRelation<UUID, UUID>> = []
        var lCheckList: OrderedSet<UUID> = []
        var rCheckList: OrderedSet<UUID> = []
        
        for relation in relations {
            var lIds: OrderedSet<UUID> = []
            var rIds: OrderedSet<UUID> = []
            
            for l in relation.left {
                lIds.append(l.id)
                if l.__m == nil { lCheckList.append(l.id) }
            }
            
            for r in relation.right {
                rIds.append(r.id)
                if r.__m == nil { rCheckList.append(r.id) }
            }
            
            idRelations.append(.init(left: lIds, right: rIds))
        }
        
        return __manyToManyBase(
            on: db,
            idRelations,
            type: (Left.self, Right.self),
            action: action,
            label: label,
            errThrowing: errThrowing,
            pivotType: pivotType,
            checkList: .list(left: lCheckList, right: rCheckList),
            reversed: false
        )
    }
    
    func __manyToManyReversed<Left, Right, PivotT>(
        on db: PGDatabase,
        _ relations: OrderedSet<MTMRelation<Left, Right>>,
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type
    ) -> EventLoopRes<Void, E>
        where Left: __Model, Right: __Model, PivotT: PivotType,
              PivotT.SecondaryModel == Left.SQLModel,
              PivotT.PrimaryModel == Right.SQLModel
    {
        var idRelations: OrderedSet<MTMRelation<UUID, UUID>> = []
        var lCheckList: OrderedSet<UUID> = []
        var rCheckList: OrderedSet<UUID> = []
        
        for relation in relations {
            var lIds: OrderedSet<UUID> = []
            var rIds: OrderedSet<UUID> = []
            
            for l in relation.left {
                lIds.append(l.id)
                if l.__m == nil { lCheckList.append(l.id) }
            }
            
            for r in relation.right {
                rIds.append(r.id)
                if r.__m == nil { rCheckList.append(r.id) }
            }
            
            idRelations.append(.init(left: lIds, right: rIds))
        }
        
        return __manyToManyBase(
            on: db,
            idRelations,
            type: (Right.self, Left.self),
            action: action,
            label: label,
            errThrowing: errThrowing,
            pivotType: pivotType,
            checkList: .list(left: lCheckList, right: rCheckList),
            reversed: true
        )
    }
    
    func __manyToMany<Left, Right, PivotT>(
        on db: PGDatabase,
        _ relations: OrderedSet<MTMRelation<UUID, UUID>>,
        type: (Left.Type, Right.Type),
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type,
        checkList: ManytoManyCheckList
    ) -> EventLoopRes<Void, E>
        where Left: __Model, Right: __Model, PivotT: PivotType,
              PivotT.PrimaryModel == Left.SQLModel,
              PivotT.SecondaryModel == Right.SQLModel
    {
        __manyToManyBase(
            on: db,
            relations,
            type: type,
            action: action,
            label: label,
            errThrowing: errThrowing,
            pivotType: pivotType,
            checkList: checkList,
            reversed: false
        )
    }
    
    func __manyToManyReversed<Left, Right, PivotT>(
        on db: PGDatabase,
        _ relations: OrderedSet<MTMRelation<UUID, UUID>>,
        type: (Left.Type, Right.Type),
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type,
        checkList: ManytoManyCheckList // right, left 顺序，与 relations 顺序相同
    ) -> EventLoopRes<Void, E>
        where Left: __Model, Right: __Model, PivotT: PivotType,
              PivotT.SecondaryModel == Left.SQLModel,
              PivotT.PrimaryModel == Right.SQLModel
    {
        __manyToManyBase(
            on: db,
            relations,
            type: (Right.self, Left.self),
            action: action,
            label: label,
            errThrowing: errThrowing,
            pivotType: pivotType,
            checkList: checkList,
            reversed: true
        )
    }
    
    private func __manyToManyBase<Left, Right, PivotT>(
        on db: PGDatabase,
        _ relations: OrderedSet<MTMRelation<UUID, UUID>>,
        type: (Left.Type, Right.Type),
        action: ManyToManyAction,
        label: String,
        errThrowing: E,
        pivotType: PivotT.Type,
        checkList: ManytoManyCheckList,
        reversed: Bool  // 只对 relations 和 checkList 生效反序，其他参数不生效
    ) -> EventLoopRes<Void, E>
        where Left: __Model, Right: __Model, PivotT: PivotType,
              PivotT.PrimaryModel == Left.SQLModel,
              PivotT.SecondaryModel == Right.SQLModel
    {
        db.trans(throws: errThrowing, "数据库事务执行失败", category: .internal) { db in
            var check: EventLoopRes<Void, E> = db.eventLoop.makeSucceededVoidResult()
            
            let lList: OrderedSet<UUID>
            let rList: OrderedSet<UUID>
            
            switch checkList {
            case .all:
                lList = reversed ? .init(relations.flatMap { $0.right }) : .init(relations.flatMap { $0.left })
                rList = reversed ? .init(relations.flatMap { $0.left }) : .init(relations.flatMap { $0.right })
            case .list(let left, let right):
                lList = reversed ? right : left
                rList = reversed ? left : right
            }
            
            if lList.count > 0 {
                check = check.flatMap {
                    self.__check(
                        on: db,
                        ids: lList,
                        for: Left.self,
                        label: label,
                        errThrowing: errThrowing
                    ).flatMap { diffs in
                        guard diffs.count == 0 else {
                            return db.eventLoop.makeFailedResult(errThrowing, "\(label) 所提供的 \(Left.logName) ID 列表中有无效项，未在数据库中找到", metadata: ["invalid": .data(diffs)], category: .external(userdata: .init(HTTPResponseStatus.unprocessableEntity)))
                        }
                        return db.eventLoop.makeSucceededVoidResult()
                    }
                }
            }
            
            if rList.count > 0 {
                check = check.flatMap {
                    self.__check(
                        on: db,
                        ids: rList,
                        for: Right.self,
                        label: label,
                        errThrowing: errThrowing
                    ).flatMap { diffs in
                        guard diffs.count == 0 else {
                            return db.eventLoop.makeFailedResult(errThrowing, "\(label) 所提供的 \(Right.logName) ID 列表中有无效项，未在数据库中找到", metadata: ["invalid": .data(diffs)], category: .external(userdata: .init(HTTPResponseStatus.unprocessableEntity)))
                        }
                        return db.eventLoop.makeSucceededVoidResult()
                    }
                }
            }
            
            return check.flatMap {
                relations.flatMap { relation in
                    switch action {
                    case .attach:
                        relation.left.flatMap { l in
                            relation.right.map { r in
                                let pivot = Pivot<PivotT>()
                                pivot.$primaryModel.id = reversed ? r : l
                                pivot.$secondaryModel.id = reversed ? l : r
                                return pivot.create(on: db)
                                    .withError(errThrowing, "将 \(label) 关系插入中间表时失败", category: .internal)
                            }
                        }
                    case .detach:
                        [
                            Pivot<PivotT>.query(on: db)
                                .filter(\.$primaryModel.$id ~~ (reversed ? relation.right : relation.left))
                                .filter(\.$secondaryModel.$id ~~ (reversed ? relation.left : relation.right))
                                .count()
                                .withError(errThrowing, "查询 \(label) 关系中间表时失败", category: .internal)
                                .flatMap
                            { count in
                                let expect = relation.right.count * relation.left.count
                                guard count == expect else {
                                    return db.eventLoop.makeFailedResult(errThrowing, "\(label) 关系解除失败，预期解除 \(expect) 条关系", metadata: ["count": .stringConvertible(count)], category: .internal)
                                }
                                
                                return db.eventLoop.makeSucceededVoidResult()
                            }.flatMap {
                                Pivot<PivotT>.query(on: db)
                                    .filter(\.$primaryModel.$id ~~ (reversed ? relation.right : relation.left))
                                    .filter(\.$secondaryModel.$id ~~ (reversed ? relation.left : relation.right))
                                    .delete()
                                    .withError(errThrowing, "将 \(label) 关系中间表移除时失败", category: .internal)
                            }
                        ]
                    }
                }.flatten(on: db.eventLoop)
            }
        }
    }
}

package enum ManyToManyAction {
    case attach
    case detach
}

package enum ManytoManyCheckList {
    case all
    case list(left: OrderedSet<UUID>, right: OrderedSet<UUID>)
}

package func SortingSQL(uuids: OrderedSet<UUID>) -> String {
    let sqlArrayContent = uuids
        .map { "'\($0.uuidString)'" }
        .joined(separator: ", ")

    return "array_position(ARRAY[\(sqlArrayContent)]::uuid[], id)"
}
