import Fluent
import NIOAdvanced
import PgSQL
import Vapor
import ErrorHandle
import ACL

protocol Controller: Sendable {
    var db: PrivilegeSystem.PGDatabase { get }
    var eventLoop: EventLoop { get }
    
    init(system: PrivilegeSystem)
}

extension Controller {
    func __createWithACL<T, G, M: PGModel>(
        models: [T],
        label: String,
        errThrowing: PrivilegeSystem.Errcase,
        aclBuilder: @Sendable @escaping (T) -> [ACLExp<M>],
        modelBuilder: @Sendable @escaping (T, UUID) -> M,
        dtoBuilder: @Sendable @escaping (M) -> Res<G, PrivilegeSystem.Errcase>
    ) -> EventLoopRes<[G], PrivilegeSystem.Errcase> {
        let orgAcls = models.map { aclBuilder($0) }
        
        var aclIds: [UUID] = []
        for a in orgAcls {
            guard let aclId = a.first?.id else {
                return db.eventLoop.makeFailedResult(errThrowing.d("传入的 AST 没有任何结构", category: .external))
            }
            aclIds.append(aclId)
        }
        
        let acls = orgAcls.flatMap { $0 }
        let r = models.enumerated().map { modelBuilder($0.element, aclIds[$0.offset]) }
        
        return db.trans { db in
            acls
                .create(on: db)
                .withError(errThrowing, "插入 ACL 记录失败", category: .internal)
                .flatMap
            {
                r.create(on: db).withError(errThrowing, "插入\(label)失败", category: .internal)
            }.flatMapThrowing { () throws(PrivilegeSystem.Errcase.ErrType) in
                try r.map { i throws(PrivilegeSystem.Errcase.ErrType) in try dtoBuilder(i).get() }
            }
        }
    }
    
    func __delete<T: PGModel>(
        _ model: T.Type = T.self,
        ids: Set<UUID>,
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
                        return try dtoBuilder(d).get()
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
                return try dtoBuilder(d).get()
            }
        }
    }
}

func SortingSQL(uuids: [UUID]) -> String {
    let sqlArrayContent = uuids
        .map { "'\($0.uuidString)'" }
        .joined(separator: ", ")

    return "array_position(ARRAY[\(sqlArrayContent)]::uuid[], id)"
}
