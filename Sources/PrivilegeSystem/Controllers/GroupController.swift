import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    public final class GroupController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
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
        
        public func create(
            groups: [DTO.Group<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
            // 创建组，需要修改 groups 表，也需要修改 group_paths 内接表
            // 通过一个 pg 事务包括，保证两个表的修改为一个原子操作
            let logger = getActionLogger()
            logger.info("执行 创建用户组 操作", metadata: ["groups": .summaryData(groups)])
            logger.debug("操作参数", metadata: ["groups": .data(groups)])
            return db.trans { db in
                self.__create(
                    on: db,
                    dtos: groups,
                    label: "群组",
                    errThrowing: .userInfoCreateFailed,
                    modelBuilder: { $0.raw() },
                    dtoBuilder: { DTO.Group<DTO.Queried>.make(from: $0.fill()) }
                ).flatMap { res in
                    // 创建表，更新 group_paths 内接表
                    res.map { group in
                        var r = db.eventLoop.makeSucceededVoidResult(throws: Errcase.ErrType.self)
                        
                        if let parentId = group.parentId {
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
                            let cycle = UGroup.Path()
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
        
        public func delete(
            groupIds: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            // 删除组，必须先清理 group_paths 表中的内接链接
            // 再从 groups 主表中批量删除表
            // 同时，删除父组意味着其下的所有子群组也会被删除
            // 通过一个 pg 事务包括，保证两个表的修改为一个原子操作
            let logger = getActionLogger()
            logger.info("执行 删除用户组 操作", metadata: ["groupIds": .summaryData(groupIds)])
            logger.debug("操作参数", metadata: ["groupIds": .data(groupIds)])
            return db.trans { db in
                self.__satisfyCheck(
                    on: db,
                    UGroup.self,
                    ids: groupIds,
                    allSatisfy: allSatisfy,
                    label: "用户群组",
                    errThrowing: .groupDeleteFailed,
                    fieldBuilder: { $0.field(\.$id) },
                    filterBuilder: { $0.filter(\.$id ~~ groupIds) }
                ).flatMap {
                    EventLoopRes<Set<UUID>, Errcase>.whenAllSucceed(
                        groupIds.map { id in
                            // 先去内接表中，揪出当前组及其所有下属子孙的 ID 集合
                            UGroup.Path.query(on: db)
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
                    ).flatMap { ids in
                        let targetIDs = ids.reduce(into: Set<UUID>()) { $0.formUnion($1) }
                        
                        // 批量抹去内接表中所有以这些组为“后代”的路径
                        return UGroup.Path.query(on: db)
                            .filter(\.$descendant.$id ~~ targetIDs)
                            .delete()
                            .withError(Errcase.groupDeleteFailed, "内接表级联删除路径失败", category: .internal)
                            .flatMap
                        {
                            // 最后在主表中把这些组真正物理切除（因为有外键，需要先删内接表再删主表）
                            UGroup.query(on: db)
                                .filter(\.$id ~~ targetIDs)
                                .delete()
                                .withError(Errcase.groupDeleteFailed, "群组主表删除失败", category: .internal)
                        }
                    }
                }
            }.logIfFail(logger: logger)
        }
        
        public func update(
            with updater: DTO.Group<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Group<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新用户组 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新用户组 详细请求数据", metadata: ["data": .data(updater)])
            return __update(
                on: db,
                updater: updater,
                label: "用户群组",
                errThrowing: .groupUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.groupId) },
                dtoBuilder: { DTO.Group<DTO.Queried>.make(from: $0) }
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
    
    func join(
        @MTMRelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        join(relations: content())
    }
    
    // MARK: - 用户移出群组
    
    func kick(
        @MTMRelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        kick(relations: content())
    }
}

public extension PrivilegeSystem.GroupController {
    // MARK: - 用户加入群组
    
    func join(
        relations: [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 用户加入群组 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("用户加入群组关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "用户组与用户",
            errThrowing: .userJoinGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { _ in logger.info("用户加入群组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 用户移出群组
    
    func kick(
        relations: [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 用户移出群组 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("用户移出群组关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "用户组与用户",
            errThrowing: .userKickGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { _ in logger.info("用户移出群组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 群组移动至父群组
    
    func move(
        _ relation: OTORelation<DTO.Group<DTO.Queried>, DTO.Group<DTO.Queried>?>
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 群组移动 操作", metadata: ["groupId": .stringConvertible(relation.left.id), "targetParentId": .string(relation.right.map { $0.id.uuidString } ?? "nil")])
        return db.trans { tdb in
            // 新上级不能是自己，也不能是自己的子孙（防止形成环形死循环）
            UGroup.Path.query(on: tdb)
                .filter(\.$ancestor.$id == relation.left.id)
                .all()
                .withError(PrivilegeSystem.Errcase.groupMoveFailed, "获取子树失败", category: .internal)
                .flatMap
            { subTreePaths in
                // 拿到 B 及其所有子孙的 ID 集合（诛九族名单）
                let subTreeIDs = Set(subTreePaths.map { $0.$descendant.id })
                
                // 检查：如果新上级在 subTreeIDs 里面，立刻抛出异常熔断
                if let superId = relation.right?.id, subTreeIDs.contains(superId) {
                    return tdb.eventLoop.makeFailedResult(PrivilegeSystem.Errcase.groupMoveFailed, "不可将群组移动到自己或子群中", category: .external) // 非法操作拦截
                }
                
                // 更新主表 groups
                relation.left.model.$parent.id = relation.right?.id
                
                return relation.left.model.update(on: tdb)
                    .withError(PrivilegeSystem.Errcase.groupMoveFailed, "更新群组主表上级失败", category: .internal)
                    .flatMap
                {
                    // 只要后代在 B 圈子里，且祖先不在 B 圈子里（属于外部老祖先），通通干掉
                    UGroup.Path.query(on: tdb)
                        .filter(\.$descendant.$id ~~ subTreeIDs)
                        .filter(\.$ancestor.$id !~ subTreeIDs)
                        .delete()
                        .withError(PrivilegeSystem.Errcase.groupMoveFailed, "断开旧链失败", category: .internal)
                        .flatMap
                    {
                        // 如果是移到最顶层（新上级为 nil），到这一步旧链断完就结束了，直接返回成功
                        guard let superId = relation.right?.id else {
                            return tdb.eventLoop.makeSucceededVoidResult()
                        }
                        
                        // 捞出“新父级 X 及其所有祖先”，跟“B 及其子孙”进行交叉组合
                        return UGroup.Path.query(on: tdb)
                            .filter(\.$descendant.$id == superId)
                            .all()
                            .withError(PrivilegeSystem.Errcase.groupMoveFailed, "获取新父级祖先链失败", category: .internal)
                            .flatMap
                        { superTreePaths in
                            // 批量并发构建新路径组合（笛卡尔积）
                            superTreePaths.flatMap { superPath in
                                subTreePaths.filter { $0.$ancestor.id == relation.left.id }.map { subPath in
                                    let newPath = UGroup.Path()
                                    newPath.$ancestor.id = superPath.$ancestor.id
                                    newPath.$descendant.id = subPath.$descendant.id
                                    // 新距离 = 祖先到X的距离 + 子孙到B的距离 + 1
                                    newPath.depth = superPath.depth + subPath.depth + 1
                                    
                                    return newPath.save(on: tdb)
                                        .withError(PrivilegeSystem.Errcase.groupMoveFailed, "批量重建新链失败", category: .internal)
                                }
                            }.flatten(on: tdb.eventLoop)
                        }
                    }
                }
            }
        }
        .map { logger.info("群组移动 操作成功") }
        .logIfFail(logger: logger)
    }
}

public extension PrivilegeSystem.GroupController {
    func query(
        relations: [DTO.UserInGroupRelation<DTO.Prepare>],
        strict: Bool = true
    ) -> EventLoopRes<[DTO.UserInGroupRelation<DTO.Queried>], PrivilegeSystem.Errcase> {
        __query(on: db, relations: relations, strict: strict)
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
        relations: [DTO.UserInGroupRelation<DTO.Prepare>],
        strict: Bool
    ) -> EventLoopRes<[UserGroupPivot], PrivilegeSystem.Errcase> {
        UserGroupPivot.query(on: db)
            .with(\.$user)
            .with(\.$group)
            .filter(\.$user.$id ~~ relations.map { $0.user.id })
            .filter(\.$group.$id ~~ relations.map { $0.group.id })
            .all()
            .withError(PrivilegeSystem.Errcase.userGroupRelationQueryFailed, "数据库查询时出错", category: .internal)
            .flatMapThrowing
        { rs throws(PrivilegeSystem.Errcase.ErrType) in
            if strict {
                guard rs.count == relations.count else {
                    throw PrivilegeSystem.Errcase.userGroupRelationQueryFailed.d("所查到的关系数量与提供的不符", category: .external)
                }
            }
            return rs
        }
    }
}
