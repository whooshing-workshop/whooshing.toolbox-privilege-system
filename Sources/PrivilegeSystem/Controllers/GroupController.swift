import Query
import Foundation
import PrivilegeModule
import NIOHTTP1

extension PrivilegeSystem {
    /// 群组控制器，提供对于群组结构的完整生命周期管理。
    ///
    /// 群组是一系列用户的集合。在系统中，群组可以具有**层级结构**，通过在创建时指定 `parentId` 
    /// 或通过 `move` 操作更改其父节点，即可实现复杂的树状组织结构。
    ///
    /// - `create`: 创建单层或多层群组。
    /// - `join` / `kick`: 管理群组内的成员（用户）。
    /// - `move`: 将子群组移动至不同的父群组下。
    ///
    /// 底层使用 `group_paths` 表（闭包表 Closure Table 模式）实现高效的层级继承与查询。
    public final class GroupController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        /// 操作记录日志器。
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.logger = logger
        }
        
        /// 创建并持久化一批群组。
        ///
        /// 创建时如果指定了 `parentId`，系统会自动维护层级闭包表（Closure Table）的深度路径。
        ///
        /// - Parameter groups: 准备入库的群组列表（`DTO.Prepare` 状态）。
        /// - Returns: `QGroup` 表示已成功存入数据库的群组列表，包含 `id`。
        ///
        /// ```swift
        /// let childGroup = try await system.group.create(
        ///     groups: [.init(name: "SubGroup", parentId: parentGroup.id)]
        /// ).get().first!
        /// ```
        public func create(
            groups: OrderedSet<PGroup>,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<[QGroup], Errcase> {
            // 创建组，需要修改 groups 表，也需要修改 group_paths 内接表
            // 通过一个 pg 事务包括，保证两个表的修改为一个原子操作
            let logger = getActionLogger()
            logger.info("执行 创建用户组 操作", metadata: ["groups": .summaryData(groups)])
            logger.debug("操作参数", metadata: ["groups": .data(groups)])
            let db = transactor?.db ?? self.db
            return db.trans(throws: .userInfoCreateFailed, "数据库事务执行失败", category: .internal) { db in
                self.__create(
                    on: db,
                    dtos: groups,
                    label: "群组",
                    errThrowing: .userInfoCreateFailed,
                    modelBuilder: { .success($0.raw()) },
                    dtoBuilder: { QGroup.make(from: $0.fill()) }
                ).flatMap { res in
                    // 创建表，更新 group_paths 内接表
                    res.map { group in
                        var r = db.eventLoop.makeSucceededVoidResult(throws: Errcase.ErrType.self)
                        
                        if let parentId = group.$parent.id {
                            // 继承父辈路径：找出所有“能够到达 A”的祖先路径，复制它们，并将它们的后代改成 B，depth 在原来的基础上 +1。
                            r = r.flatMap {
                                db.raw(
                                    """
                                    INSERT INTO group_paths (id, ancestor_id, descendant_id, depth)
                                    SELECT 
                                        gen_random_uuid() AS id, 
                                        ancestor_id, 
                                        \(bind: group.id)::uuid AS descendant_id, 
                                        (depth + 1) AS depth
                                    FROM group_paths
                                    WHERE descendant_id = \(bind: parentId)::uuid
                                    """
                                )
                                .run()
                                .withError(Errcase.groupCreateFailed, "内接表捞表操作失败", category: .internal)
                            }
                        }
                        
                        return r.flatMap {
                            // 添加自身路径：插入一条 B -> B，depth = 0 的自循环路径。
                            let cycle = __SDBM.Group.Path()
                            cycle.$ancestor.id = group.id
                            cycle.$descendant.id = group.id
                            cycle.depth = 0
                            
                            return cycle.save(on: db)
                                .withError(Errcase.groupCreateFailed, "内接表自循环路径创建失败", category: .internal)
                        }
                    }.flatten(on: db.eventLoop).map { res }
                }
            }
            .map { 
                logger.info("创建用户组 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("创建用户组 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
        
        /// 删除指定的群组。
        ///
        /// 连带删除该群组在闭包表中的所有后代关联，以及级联切除子群组树。
        /// - Parameters:
        ///   - groupIds: 要删除的群组 ID 集合。
        ///   - allSatisfy: 是否必须满足全部找到并删除。
        /// - Returns: `EventLoopRes<Void, Errcase>`
        public func delete(
            groupIds: OrderedSet<UUID>,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<Void, Errcase> {
            // 删除组，必须先清理 group_paths 表中的内接链接
            // 再从 groups 主表中批量删除表
            // 同时，删除父组意味着其下的所有子群组也会被删除
            // 通过一个 pg 事务包括，保证两个表的修改为一个原子操作
            let logger = getActionLogger()
            logger.info("执行 删除用户组 操作", metadata: ["groupIds": .summaryData(groupIds)])
            logger.debug("操作参数", metadata: ["groupIds": .data(groupIds)])
            let db = transactor?.db ?? self.db
            return db.trans(throws: .groupDeleteFailed, "数据库事务执行失败", category: .internal) { db in
                self.__check(
                    on: db,
                    ids: groupIds,
                    for: QGroup.self,
                    label: "用户群组",
                    errThrowing: .groupDeleteFailed
                ).flatMap { diffs in
                    guard diffs.count == 0 else {
                        return db.eventLoop.makeFailedResult(Errcase.groupDeleteFailed, "预期记录未在数据库中找到", metadata: ["invalid": .data(diffs)], category: .external(userdata: .init(HTTPResponseStatus.notFound)))
                    }
                    
                    return db.eventLoop.makeSucceededVoidResult()
                }.flatMap {
                    EventLoopRes<Set<UUID>, Errcase>.whenAllSucceed(
                        groupIds.map { id in
                            // 先去内接表中，揪出当前组及其所有下属子孙的 ID 集合
                            __SDBM.Group.Path.query(on: db)
                                .filter(\.$ancestor.$id == id)
                                .all()
                                .withError(Errcase.groupDeleteFailed, "获取子树节点失败", category: .internal)
                                .map
                            { paths in
                                // 提取出所有需要连坐删除的组 ID（去重确保安全）
                                Set(paths.map { $0.$descendant.id })
                            }
                        },
                        on: db.eventLoop
                    )
                }.flatMap { ids in
                    let targetIDs = ids.reduce(into: Set<UUID>()) { $0.formUnion($1) }
                    
                    // 批量抹去内接表中所有以这些组为“后代”的路径
                    return __SDBM.Group.Path.query(on: db)
                        .filter(\.$descendant.$id ~~ targetIDs)
                        .delete()
                        .withError(Errcase.groupDeleteFailed, "内接表级联删除路径失败", category: .internal)
                        .flatMap
                    {
                        // 最后在主表中把这些组真正物理切除（因为有外键，需要先删内接表再删主表）
                        __SDBM.Group.query(on: db)
                            .filter(\.$id ~~ targetIDs)
                            .delete()
                            .withError(Errcase.groupDeleteFailed, "群组主表删除失败", category: .internal)
                    }
                }
            }.logIfFail(logger: logger)
        }
        
        /// 更新群组。
        ///
        /// 仅用于更新基本信息如名称。不适用于层级关系的变更，如果需要变更层级结构，请使用 `move` 函数。
        /// - Parameter updater: 更新器对象 `PGroup.Updater`。
        /// - Returns: `QGroup`
        public func update(
            with updater: PGroup.Updater,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<QGroup, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新用户组 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新用户组 详细请求数据", metadata: ["data": .data(updater)])
            let db = transactor?.db ?? self.db
            return __update(
                on: db,
                updater: updater,
                label: "用户群组",
                errThrowing: .groupUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.groupId) },
                dtoBuilder: { QGroup.make(from: $0) }
            )
            .map { 
                logger.info("更新用户组 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("更新用户组 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
    }
}

public extension PrivilegeSystem.GroupController {
    // MARK: - 用户加入群组
    
    /// 将一个或多个用户加入到特定群组。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func join(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        userToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        join(userToGroup: content(), on: transactor)
    }
    
    /// 将一个或多个用户加入到特定群组。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func join(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QUser, QGroup>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        join(relations: content(), on: transactor)
    }
    
    // MARK: - 用户移出群组
    
    /// 将一个或多个用户从群组中移出。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func kick(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        userFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        kick(userFromGroup: content(), on: transactor)
    }
    
    /// 将一个或多个用户从群组中移出。
    ///
    /// - Parameter content: `MTMRelationBuilder` 多对多关系构建器。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func kick(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QUser, QGroup>>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        kick(relations: content(), on: transactor)
    }
}

public extension PrivilegeSystem.GroupController {
    // MARK: - 用户加入群组
    
    /// 将一个或多个用户加入到特定群组。
    ///
    /// - Parameter relations: `MTMRelation` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func join(
        userToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 用户加入群组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("用户加入群组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            type: (QUser.self, QGroup.self),
            action: .attach,
            label: "用户组与用户",
            errThrowing: .userJoinGroupFailed,
            pivotType: __SDBM.Pivots.UserGroup.self,
            checkList: .all
        )
        .map { _ in logger.info("用户加入群组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    /// 将一个或多个用户加入到特定群组。
    ///
    /// - Parameter relations: `MTMRelation` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func join(
        relations: OrderedSet<MTMRelation<QUser, QGroup>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 用户加入群组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("用户加入群组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "用户组与用户",
            errThrowing: .userJoinGroupFailed,
            pivotType: __SDBM.Pivots.UserGroup.self
        )
        .map { _ in logger.info("用户加入群组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 用户移出群组
    
    /// 将一个或多个用户从特定群组移除。
    ///
    /// - Parameter relations: `MTMRelation` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func kick(
        userFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 用户移出群组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("用户移出群组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            type: (QUser.self, QGroup.self),
            action: .detach,
            label: "用户组与用户",
            errThrowing: .userKickGroupFailed,
            pivotType: __SDBM.Pivots.UserGroup.self,
            checkList: .all
        )
        .map { _ in logger.info("用户移出群组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    /// 将一个或多个用户从特定群组移除。
    ///
    /// - Parameter relations: `MTMRelation` 多对多关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func kick(
        relations: OrderedSet<MTMRelation<QUser, QGroup>>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 用户移出群组 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("用户移出群组关系详情", metadata: ["detail": .data(relations)])
        let db = transactor?.db ?? self.db
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "用户组与用户",
            errThrowing: .userKickGroupFailed,
            pivotType: __SDBM.Pivots.UserGroup.self
        )
        .map { _ in logger.info("用户移出群组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 群组移动至父群组
    
    /// 移动整个群组（含子群组）到新的父群组节点下。
    ///
    /// 底层将自动完成闭包表记录的重建及死锁检查。
    ///
    /// - Parameter relation: `OTORelation` 描述从源群组到目标群组（可以为 nil）的一对一关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func move(
        _ relation: OTORelation<UUID, UUID?>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 群组移动 操作", metadata: ["relation": .summaryData(relation)])
        logger.info("群组移动操作详情", metadata: ["relation": .data(relation)])
        
        let db = transactor?.db ?? self.db
        let ids = relation.right == nil ? [relation.left] : [relation.left, relation.right!]
        
        return db.trans(throws: .groupMoveFailed, "数据库事务执行失败", category: .internal) { db in
            __SDBM.Group.query(on: db)
                .filter(\.$id ~~ ids)
                .all()
                .withError(PrivilegeSystem.Errcase.groupMoveFailed, "从数据库中检索 Group 失败", category: .internal)
                .flatMapThrowing
            { models throws(PrivilegeSystem.Errcase.ErrType) in
                guard models.count == ids.count else {
                    throw PrivilegeSystem.Errcase.groupMoveFailed.d("要移动的群组中有不存在项", category: .external(suggestions: ["群组必须存在才可移动"], userdata: .init(HTTPResponseStatus.forbidden))).metadata(["model_ids_in_db": .data(models.map { $0.id })])
                }
                let left = try readGroup(id: relation.left, from: models)
                let right = models.count == 2 ? try readGroup(id: relation.right!, from: models) : nil
                return (left, right)
            }.flatMapResult { left, right in
                QGroup.make(from: left).flatMap { l in
                    guard let r = right else { return .success((l, nil)) }
                    return QGroup
                        .make(from: r)
                        .map { r in (l, r) }
                }.mapError(as: PrivilegeSystem.Errcase.groupMoveFailed, "从数据库模型创建 QGroup 失败", category: .inherit)
            }.flatMap { left, right in
                self.__move(db: db, .init(left: left, right: right))
            }
        }.map { logger.info("群组移动 操作成功") }
        .logIfFail(logger: logger)
        
        @Sendable
        func readGroup(id: UUID, from arr: [__SDBM.Group]) throws(PrivilegeSystem.Errcase.ErrType) -> __SDBM.Group {
            let left = try required(throws: PrivilegeSystem.Errcase.groupMoveFailed, "Group ID 读取失败", category: .internal) {
                try arr.first { try $0.requireID() == id }
            }
            guard let l = left else {
                throw PrivilegeSystem.Errcase.groupMoveFailed.d("数据库读取到的 ID 不匹配", category: .internal).metadata(["not_found": .stringConvertible(id)])
            }
            return l
        }
    }
    
    /// 移动整个群组（含子群组）到新的父群组节点下。
    ///
    /// 底层将自动完成闭包表记录的重建及死锁检查。
    ///
    /// - Parameter relation: `OTORelation` 描述从源群组到目标群组（可以为 nil）的一对一关系。
    /// - Returns: `EventLoopRes<Void, Errcase>`
    func move(
        _ relation: OTORelation<QGroup, QGroup?>,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 群组移动 操作", metadata: ["relation": .summaryData(relation)])
        logger.info("群组移动操作详情", metadata: ["relation": .data(relation)])
        
        let db = transactor?.db ?? self.db
        
        return __move(db: db, relation)
            .map { logger.info("群组移动 操作成功") }
            .logIfFail(logger: logger)
    }
}

extension PrivilegeSystem.GroupController {
    func __move(
        db: PGDatabase,
        _ relation: OTORelation<QGroup, QGroup?>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        db.trans(throws: .groupMoveFailed, "数据库事务执行失败", category: .internal) { tdb in
            let oldDelete: EventLoopRes<[__SDBM.Group.Path], PrivilegeSystem.Errcase> = __SDBM.Group.Path.query(on: tdb)
                .filter(\.$ancestor.$id == relation.left.id)
                .all()
                .withError(PrivilegeSystem.Errcase.groupMoveFailed, "获取子树失败", category: .internal)
                .flatMap
            { subTreePaths in
                // 拿到 B 及其所有子孙的 ID 集合（诛九族名单）
                let subTreeIDs = Set(subTreePaths.map { $0.$descendant.id })
                
                // 新上级不能是自己，也不能是自己的子孙（防止形成环形死循环）
                // 检查：如果新上级在 subTreeIDs 里面，立刻抛出异常熔断
                if let superId = relation.right?.id, subTreeIDs.contains(superId) {
                    return tdb.eventLoop.makeFailedResult(PrivilegeSystem.Errcase.groupMoveFailed, "不可将群组移动到自己或子群中", category: .external(userdata: .init(HTTPResponseStatus.forbidden))) // 非法操作拦截
                }

                return relation.left.model(from: tdb)
                    .errCast(PrivilegeSystem.Errcase.groupMoveFailed, "获取主表失败", category: .internal)
                    .flatMap
                { leftModel in
                    // 更新主表 groups
                    leftModel.$parent.id = relation.right?.id
                    
                    return leftModel.update(on: tdb)
                        .withError(PrivilegeSystem.Errcase.groupMoveFailed, "更新群组主表上级失败", category: .internal)
                        .flatMap
                    {
                        // 只要后代在 B 圈子里，且祖先不在 B 圈子里（属于外部老祖先），通通干掉
                        __SDBM.Group.Path.query(on: tdb)
                            .filter(\.$descendant.$id ~~ subTreeIDs)
                            .filter(\.$ancestor.$id !~ subTreeIDs)
                            .delete()
                            .withError(PrivilegeSystem.Errcase.groupMoveFailed, "断开旧链失败", category: .internal)
                    }
                }.map { subTreePaths }
            }
            
            return oldDelete.flatMap { subTreePaths in
                // 如果是移到最顶层（新上级为 nil），到这一步旧链断完就结束了，直接返回成功
                guard let superId = relation.right?.id else {
                    return tdb.eventLoop.makeSucceededVoidResult()
                }
                
                // 捞出“新父级 X 及其所有祖先”，跟“B 及其子孙”进行交叉组合
                return __SDBM.Group.Path.query(on: tdb)
                    .filter(\.$descendant.$id == superId)
                    .all()
                    .withError(PrivilegeSystem.Errcase.groupMoveFailed, "获取新父级祖先链失败", category: .internal)
                    .flatMap
                { superTreePaths in
                    // 批量并发构建新路径组合（笛卡尔积）
                    superTreePaths.flatMap { superPath in
                        subTreePaths.filter { $0.$ancestor.id == relation.left.id }.map { subPath in
                            let newPath = __SDBM.Group.Path()
                            newPath.$ancestor.id = superPath.$ancestor.id
                            newPath.$descendant.id = subPath.$descendant.id
                            // 新距离 = 祖先到X的距离 + 子孙到B的距离 + 1
                            newPath.depth = superPath.depth + subPath.depth + 1
                            
                            return newPath.save(on: tdb).withError(PrivilegeSystem.Errcase.groupMoveFailed, "批量重建新链失败", category: .internal)
                        }
                    }.flatten(on: tdb.eventLoop)
                }
            }
        }
    }
}

public extension PrivilegeSystem.GroupController {
    /// 查询“某用户在某群组的组内关系（UserInGroupRelation）”是否存在并转换为查询模型。
    ///
    /// `UserInGroupRelation` 一般用于指派特定的组内角色给某个用户。
    ///
    /// - Parameters:
    ///   - relations: 预期需查询的关系，包含用户 DTO 和群组 DTO。
    ///   - strict: 如果为 `true`，查出的记录条数不匹配预期的 `relations` 长度则抛出失败。
    /// - Returns: `EventLoopRes<[UserTGroup], Errcase>`
    func query(
        relations: OrderedSet<PUserTGroup>,
        strict: Bool = true,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<[UserTGroup], PrivilegeSystem.Errcase> {
        let db = transactor?.db ?? self.db
        return __query(on: db, relations: relations, strict: strict)
            .flatMapThrowing
        { rs throws(PrivilegeSystem.Errcase.ErrType) in
            try required(throws: PrivilegeSystem.Errcase.userGroupRelationQueryFailed, category: .internal) {
                try rs.map {
                    try .make(from: $0).get()
                }
            }
        }
    }
}
 
extension PrivilegeSystem.GroupController {
    func __query(
        on db: PGDatabase,
        relations: OrderedSet<PUserTGroup>,
        strict: Bool
    ) -> EventLoopRes<[__SDBM.UserGroupPivot], PrivilegeSystem.Errcase> {
        __SDBM.UserGroupPivot.query(on: db)
            .with(\.$primaryModel)
            .with(\.$secondaryModel)
            .filter(\.$primaryModel.$id ~~ relations.map { $0.userId })
            .filter(\.$secondaryModel.$id ~~ relations.map { $0.groupId })
            .all()
            .withError(PrivilegeSystem.Errcase.userGroupRelationQueryFailed, "数据库查询时出错", category: .internal)
            .flatMapThrowing
        { rs throws(PrivilegeSystem.Errcase.ErrType) in
            if strict {
                guard rs.count == relations.count else {
                    throw PrivilegeSystem.Errcase.userGroupRelationQueryFailed.d("所查到的关系数量与提供的不符", category: .external(userdata: .init(HTTPResponseStatus.unprocessableEntity))).metadata(["expect": .stringConvertible(relations.count), "got": .stringConvertible(rs.count)])
                }
            }
            return rs
        }
    }
}
