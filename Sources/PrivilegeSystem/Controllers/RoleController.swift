import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    public final class RoleController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        let groupController: GroupController
        let policyController: PolicyController
        
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            groupController: GroupController,
            policyController: PolicyController,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.groupController = groupController
            self.policyController = policyController
            self.logger = logger
        }
        
        public func create(
            @MTORelationBuilder<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            create(relations: content())
        }
        
        public func createWithReturning(
            @MTORelationBuilder<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
        ) -> EventLoopRes<[UUID: [DTO.Policy<Role, DTO.Queried>]], Errcase> {
            createWithReturning(relations: content())
        }
        
        public func create(
            roles: [DTO.Role<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建角色 操作", metadata: ["roles": .summaryData(roles)])
            logger.debug("操作参数", metadata: ["roles": .data(roles)])
            return __create(on: db, roles: roles)
                .map { logger.info("创建角色 操作成功"); return $0 }
                .logIfFail(logger: logger)
        }
        
        public func delete(
            roleIds: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除角色 操作", metadata: ["roleIds": .summaryData(roleIds)])
            logger.debug("操作参数", metadata: ["roleIds": .data(roleIds)])
            return __delete(
                on: db,
                Role.self,
                ids: roleIds,
                allSatisfy: allSatisfy,
                label: "角色",
                errThrowing: .roleDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ roleIds) }
            )
            .map { logger.info("删除角色 操作成功") }
            .logIfFail(logger: logger)
        }
        
        public func update(
            with updater: DTO.Role<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Role<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新角色 操作", metadata: ["roleId": .stringConvertible(updater.roleId)])
            return __update(
                on: db,
                updater: updater,
                label: "角色",
                errThrowing: .roleUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.roleId) },
                dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0) }
            )
            .map { logger.info("更新角色 操作成功"); return $0 }
            .logIfFail(logger: logger)
        }
    }
}

public extension PrivilegeSystem.RoleController {
    func create(
        relations: [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建角色（含策略） 操作", metadata: ["relations": .summaryData(relations)])
            logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return db.trans { db in
            self.__create(on: db, roles: relations.map { $0.right }).flatMap { _ in
                self.policyController.__create(
                    on: db,
                    to: Role.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
        .map { logger.info("创建角色（含策略） 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func createWithReturning(
        relations: [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) -> EventLoopRes<[UUID: [DTO.Policy<Role, DTO.Queried>]], PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建角色（含策略返回） 操作", metadata: ["relations": .summaryData(relations)])
            logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return db.trans { db in
            self.__create(on: db, roles: relations.map { $0.right }).flatMap { _ in
                self.policyController.__createWithReturning(
                    on: db,
                    to: Role.self,
                    relations: relations.map { .init(left: $0.left, right: $0.right.id) }
                )
            }
        }
        .map { logger.info("创建角色（含策略返回） 操作成功"); return $0 }
        .logIfFail(logger: logger)
    }
}

public extension PrivilegeSystem.RoleController {
    // MARK: - 角色任命
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.appoint(relations: content())
    }
    
    // MARK: - 角色撤职
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
    
    func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        self.dismiss(relations: content())
    }
}

public extension PrivilegeSystem.RoleController {
    // MARK: - 角色任命
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色任命用户 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色任命用户关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "角色与用户",
            errThrowing: .roleAppointUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("角色任命用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色任命用户组 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色任命用户组关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "角色与用户组",
            errThrowing: .roleAppointGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("角色任命用户组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色任命组内用户 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色任命组内用户关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "角色与群组内用户",
            errThrowing: .roleAppointGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("角色任命组内用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色任命组内用户（Prepare） 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色任命组内用户（Prepare）关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .attach,
            label: "角色与群组内用户",
            errThrowing: .roleAppointGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { self.groupController.__query(on: $0, relations: $1, strict: true) }
        )
        .map { logger.info("角色任命组内用户（Prepare） 操作成功") }
        .logIfFail(logger: logger)
    }
    
    // MARK: - 角色撤职
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色撤職用户 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色撤職用户关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "角色与用户",
            errThrowing: .roleDismissUserFailed,
            siblingBuilder: { $0.model.$users },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("角色撤職用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色撤職用户组 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色撤職用户组关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "角色与用户组",
            errThrowing: .roleDismissGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("角色撤職用户组 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色撤職组内用户 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色撤職组内用户关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "角色与群组内用户",
            errThrowing: .roleDismissGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
        .map { logger.info("角色撤職组内用户 操作成功") }
        .logIfFail(logger: logger)
    }
    
    func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 角色撤職组内用户（Prepare） 操作", metadata: ["relations": relations.asSummaryMetadata])
        logger.debug("角色撤職组内用户（Prepare）关系详情", metadata: ["detail": relations.asDetailMetadata])
        return __manyToMany(
            on: db,
            relations,
            action: .detach,
            label: "角色与群组内用户",
            errThrowing: .roleDismissGroupUserFailed,
            siblingBuilder: { $0.model.$usersInGroup },
            modelsBuilder: { self.groupController.__query(on: $0, relations: $1, strict: true) }
        )
        .map { logger.info("角色撤職组内用户（Prepare） 操作成功") }
        .logIfFail(logger: logger)
    }
}

// MARK: - 角色的验证与查询

public extension PrivilegeSystem.RoleController {
    // 一个 user 可用的所有 roles 包括:
    // 1.为 user 赋予的 用户角色
    // 2.user 所在组的 群组角色，包括所有父群组的 群组角色
    // 3.user 所在组为其赋予的 组内角色
    typealias Errcase = PrivilegeSystem.Errcase
    
    func roles(
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
        __roles(on: db, for: user)
    }
    
    func userRoles(
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
        __userRoles(on: db, for: user)
    }
    
    func groupRoles(
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[MTORelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>], Errcase> {
        __groupRoles(on: db, for: user)
    }
    
    func userInGroupRoles(
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[MTORelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>], Errcase> {
        __userInGroupRoles(on: db, for: user)
    }
}

public extension PrivilegeSystem.RoleController {
    func `is`(
        role: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<Bool, Errcase> {
        __is(on: db, role: role, appointedTo: user)
    }
    
    func `is`(
        userRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<Bool, Errcase> {
        __is(on: db, userRole: userRole, appointedTo: user)
    }
    
    func `is`(
        groupRole: DTO.Role<DTO.Queried>,
        appointedTo group: DTO.Group<DTO.Queried>
    ) -> EventLoopRes<Bool, Errcase> {
        __is(on: db, groupRole: groupRole, appointedTo: group)
    }
    
    func verify(
        groupRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
        __verify(on: db, groupRole: groupRole, appointedTo: user)
    }
    
    func verify(
        userInGroupRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
        __verify(on: db, userInGroupRole: userInGroupRole, appointedTo: user)
    }
}

extension PrivilegeSystem.RoleController {
    // 取得 某用户 所有可用的 角色
    func __roles(
        on db: PGDatabase,
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
        [
            __userRoles(on: db, for: user),
            __groupRoles(on: db, for: user).map { $0.flatMap { $0.left } },
            __userInGroupRoles(on: db, for: user).map { $0.flatMap { $0.left } }
        ].flatten(on: db.eventLoop).map {
            [DTO.Role<DTO.Queried>]($0.flatMap { $0 }.uniqued())
        }
    }
    
    // 取得 某用户 可用的所有用户角色
    func __userRoles(
        on db: PGDatabase,
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Role<DTO.Queried>], Errcase> {
        user.model.$roles.get(on: db)
            .withError(Errcase.userRoleFetchFailed, "从数据库查询失败", category: .internal)
            .flatMapThrowing
        { userRoles throws(Errcase.ErrType) in
            try required(throws: Errcase.userRoleFetchFailed, "转为 DTO 失败", category: .internal) {
                try userRoles.map { try DTO.Role<DTO.Queried>.make(from: $0).get() }
            }
        }
    }
    
    // 查询某个用户的所有可用群组角色(role)，即用户所在群组被赋予的角色，包括该群组的所有父群组
    func __groupRoles(
        on db: PGDatabase,
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[MTORelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>], Errcase> {
        user.model.$groups.query(on: db)
            .with(\.$supers) { path in
                path.with(\.$ancestor)
            }
            .all()
            .withError(Errcase.groupRoleQueryFailed, "从数据库查询失败", category: .internal)
            .flatMapThrowing
        { groupRoles throws(Errcase.ErrType) in
            let gs = [UGroup]((
                groupRoles +
                groupRoles.flatMap { $0.supers.map { $0.ancestor } }
            ).uniqued())
            
            // 安全提取所有唯一的群组 UUID 集合
            let ids = try required(throws: Errcase.arbitrateFailed, "取得群组 ID 失败", category: .internal) {
                try gs.compactMap { try $0.requireID() }
            }
            
            return (gs, ids)
        }.flatMap { groups, groupIds in
            guard !groupIds.isEmpty else {
                return db.eventLoop.makeSucceededResult([])
            }
            
            return RoleGroupPivot.query(on: db)
                .filter(\.$secondaryModel.$id ~~ groupIds)
                .with(\.$primaryModel)
                .all()
                .withError(Errcase.groupRoleQueryFailed, "取得 Role Pivot 数据失败", category: .internal)
                .flatMapThrowing
            { pivots throws(Errcase.ErrType) in
                try required(throws: Errcase.groupRoleQueryFailed, "转为 DTO 失败", category: .internal) {
                    // 在内存中把分散的 pivots 记录按照「群组的 UUID」切分揉合在一起
                    // 得到的字典：[Group_UUID: [Pivot]]
                    let groupedPivots = Dictionary(grouping: pivots, by: { $0.$secondaryModel.id })
                    
                    // 遍历聚合后的字典，组装成多对一结构的 MTORelation 数组
                    return try groupedPivots.map { groupId, currentGroupPivots in
                        guard let associatedGroup = groups.first(where: { $0.id == groupId }) else {
                            throw Errcase.arbitrationDataCollectFailed.d("群组数据映射丢失", category: .internal)
                        }
                        
                        let groupDTO = try DTO.Group<DTO.Queried>.make(from: associatedGroup).get()
                        let roleDTOs = [DTO.Role<DTO.Queried>](try currentGroupPivots.map { pivot in
                            try DTO.Role<DTO.Queried>.make(from: pivot.primaryModel).get()
                        }.uniqued())
                        
                        return MTORelation(
                            left: roleDTOs,
                            right: groupDTO
                        )
                    }
                }
            }
        }
    }
    
    // 查询某个用户的所有可用组内角色(role)
    func __userInGroupRoles(
        on db: PGDatabase,
        for user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[MTORelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>], Errcase> {
        // 1. 第一步：捞出该用户直接加入的所有群组关系，并预加载完整的 UGroup 实体
        UserGroupPivot.query(on: db)
            .filter(\.$user.$id == user.id)
            .with(\.$group)
            .all()
            .withError(Errcase.userInGroupRoleQueryFailed, "从数据库查询失败", category: .internal)
            .flatMapThrowing
        { userGroupPivots throws(Errcase.ErrType) in
            // 安全提取所有“用户-群组”关系表的主键 ID (UUID)
            try required(throws: Errcase.userInGroupRoleQueryFailed, "用户群组 pivot 的 id 获取失败", category: .internal) {
                let pivotIds = try userGroupPivots.compactMap { try $0.requireID() }
                return (userGroupPivots, pivotIds)
            }
        }.flatMap { userGroupPivots, pivotIds in
            guard !pivotIds.isEmpty else {
                return db.eventLoop.makeSucceededResult([])
            }
            
            // 2. 第二步：一发 IN 聚合查询，直击二级中间表
            return RoleUserInGroupPivot.query(on: db)
                .filter(\.$secondaryModel.$id ~~ pivotIds)
                .with(\.$primaryModel)
                .all()
                .withError(Errcase.userInGroupRoleQueryFailed, "从数据库取得 pivot 失败", category: .internal)
                .flatMapThrowing
            { pivots throws(Errcase.ErrType) in
                try required(throws: Errcase.groupRoleQueryFailed, "转为 DTO 失败", category: .internal) {
                    
                    // 3. 第三步：为了做到 O(1) 的内存装配性能，先把第一步查到的物理实体织成一张“查找表”
                    // Key 是 UserGroupPivot 的 ID，Value 是完整的 UGroup 实体
                    var pivotToGroupLookup: [UUID: UGroup] = [:]
                    for ugPivot in userGroupPivots {
                        if let ugPivotId = ugPivot.id {
                            pivotToGroupLookup[ugPivotId] = ugPivot.group
                        }
                    }
                    
                    // 4. 第四步：在内存里，把多条角色记录按照【群组自身的 ID】重新切分团聚
                    let groupedByGroup = try Dictionary(grouping: pivots, by: { pivot -> UUID in
                        // 凭借当前记录的 user_in_group_id，从刚才的查找表里瞬间拿到 group.id
                        guard let g = pivotToGroupLookup[pivot.$secondaryModel.id], let gId = g.id else {
                            throw Errcase.arbitrationDataCollectFailed.d("组内角色纽带关系映射丢失", category: .internal)
                        }
                        return gId
                    })
                    
                    // 5. 第五步：组装出符合你多对一泛型要求的 MTORelation 数组
                    return try groupedByGroup.map { groupId, currentPivots in
                        
                        // 5.1 从刚才建好的查找表里，把那个直接加入的完整的 UGroup 实体揪出来
                        // 由于同一个 groupId 对应的 UGroup 是一样的，我们直接拿 currentPivots 第一个对应的组即可
                        let samplePivotId = currentPivots[0].$secondaryModel.id
                        guard let associatedGroup = pivotToGroupLookup[samplePivotId] else {
                            throw Errcase.arbitrationDataCollectFailed.d("群组实体检索失败", category: .internal)
                        }
                        
                        let groupDTO = try DTO.Group<DTO.Queried>.make(from: associatedGroup).get()
                        
                        // 5.2 把这个组名下被特殊指派的所有角色批量映射为 Role DTO，并做内存去重
                        let roleDTOs = try Array(currentPivots.map { pivot in
                            try DTO.Role<DTO.Queried>.make(from: pivot.primaryModel).get()
                        }.uniqued())
                        
                        // 5.3 完美打包塞入多对一容器
                        return MTORelation(
                            left: roleDTOs, // 该用户在这个组内被指派的多个专属角色
                            right: groupDTO // 指派来源的直接群组（一端）
                        )
                    }
                }
            }
        }
    }
}

extension PrivilegeSystem.RoleController {
    // 检查某角色对于某用户是否可用
    func __is(
        on db: PGDatabase,
        role: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<Bool, Errcase> {
        [
            __is(on: db, userRole: role, appointedTo: user),
            __verify(on: db, groupRole: role, appointedTo: user).map { !$0.isEmpty },
            __verify(on: db, userInGroupRole: role, appointedTo: user).map { !$0.isEmpty }
        ].flatten(on: db.eventLoop).map { $0.reduce(false) { $0 || $1 } }
    }
    
    // 检查某角色是否被任命某用户
    func __is(
        on db: PGDatabase,
        userRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<Bool, Errcase> {
        user.model.$roles.query(on: db)
            .filter(\.$id == userRole.id)
            .first()
            .withError(Errcase.userRoleCheckFailed, "从数据库查询失败", category: .internal)
            .map { $0 != nil }
    }
    
    // 检查某角色是否被任命某群组为群组角色
    func __is(
        on db: PGDatabase,
        groupRole: DTO.Role<DTO.Queried>,
        appointedTo group: DTO.Group<DTO.Queried>
    ) -> EventLoopRes<Bool, Errcase> {
        group.model.$groupRoles.query(on: db)
            .filter(\.$id == groupRole.id)
            .first()
            .withError(Errcase.groupRoleCheckFailed, "从数据库查询失败", category: .internal)
            .map { $0 != nil }
    }
    
    // 验证某群组角色是否为某用户可用，若可用，指出该角色是哪个或哪些群组的群组角色
    func __verify(
        on db: PGDatabase,
        groupRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
        user.model.$groups.query(on: db)
            .with(\.$supers) { path in
                path.with(\.$ancestor)
            }
            .all()
            .withError(Errcase.groupRoleVerifyFailed, "取得用户所加入的所有群组失败", category: .internal)
            .flatMap
        { groups in
            let gs = [UGroup]((
                groups +
                groups.flatMap { $0.supers.map { $0.ancestor } }
            ).uniqued())
            
            let groupIds = gs.compactMap { $0.id }
            
            guard !groupIds.isEmpty else {
                return db.eventLoop.makeSucceededResult([])
            }
            
            let groupsLookup = Dictionary(uniqueKeysWithValues: gs.map { ($0.id, $0) })
            
            return RoleGroupPivot.query(on: db)
                .filter(\.$primaryModel.$id == groupRole.id)
                .filter(\.$secondaryModel.$id ~~ groupIds)
                .all()
                .withError(Errcase.groupRoleVerifyFailed, "校验群组角色关联失败", category: .internal)
                .flatMapThrowing
            { pivots throws(Errcase.ErrType) in
                try required(throws: Errcase.groupRoleVerifyFailed, "转为 DTO 失败", category: .internal) {
                    // 逆向匹配，把中间表捞出来的关联群组 ID 还原为完整的 Group DTO
                    try pivots.compactMap { pivot -> DTO.Group<DTO.Queried>? in
                        let pivotGroupId = pivot.$secondaryModel.id
                        
                        // 凭借外键 ID 从刚才的 lookup 字典中 O(1) 瞬间揪出原生态的、带树状血缘的 UGroup 实体
                        guard let associatedGroup = groupsLookup[pivotGroupId] else { return nil }
                        
                        // 将其整装转换为你需要的 DTO.Group 并交付出去
                        return try DTO.Group<DTO.Queried>.make(from: associatedGroup).get()
                    }
                }
            }
        }
    }
    
    // 验证某组内角色是否为某用户可用，若可用，指出该角色是哪个或哪些群组的群组角色
    func __verify(
        on db: PGDatabase,
        userInGroupRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
        RoleUserInGroupPivot.query(on: db)
            .filter(\.$primaryModel.$id == userInGroupRole.id)
            .join(UserGroupPivot.self, on: \RoleUserInGroupPivot.$secondaryModel.$id == \UserGroupPivot.$id)
            .filter(UserGroupPivot.self, \.$user.$id == user.id)
            .with(\.$secondaryModel) { userInGroup in
                // 通过 eager load，强行把内层中间表，以及中间表背后的 UGroup 实体全部批量捎带出来
                userInGroup.with(\.$group)
            }
            .all()
            .withError(Errcase.userInGroupRoleVerifyFailed, "验证组内特指派角色可用性失败", category: .internal)
            .flatMapThrowing
        { pivots throws(Errcase.ErrType) in
            try required(throws: Errcase.userInGroupRoleVerifyFailed, "转为 DTO 失败", category: .internal) {
                // 穿透复合中间表，抓出最内层的 UGroup 并映射为 Group DTO
                try pivots.map { pivot -> DTO.Group<DTO.Queried> in
                    // 1. 从二级表拿到内层表 UserGroupPivot
                    let userGroupRelation = pivot.secondaryModel
                    // 2. 从内层表拿到我们刚刚用 .with(\.$group) 提前预加载好的 UGroup 物理实体
                    let rawGroup = userGroupRelation.group
                    // 3. 完美转化为安全、干净的 DTO.Group 容器交付出去
                    return try DTO.Group<DTO.Queried>.make(from: rawGroup).get()
                }
            }
        }
    }
}

extension PrivilegeSystem.RoleController {
    public func __create(
        on db: PGDatabase,
        roles: [DTO.Role<DTO.Prepare>]
    ) -> EventLoopRes<[DTO.Role<DTO.Queried>], PrivilegeSystem.Errcase> {
        __create(
            on: db,
            dtos: roles,
            label: "角色",
            errThrowing: .roleCreateFailed,
            modelBuilder: { $0.raw() },
            dtoBuilder: { DTO.Role<DTO.Queried>.make(from: $0.fill()) }
        )
    }
}
