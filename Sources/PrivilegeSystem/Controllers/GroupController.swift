import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule

extension PrivilegeSystem {
    public final class GroupController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop
        ) {
            self.db = db
            self.eventLoop = eventLoop
        }
        
        public func create(
            groups: [DTO.Group<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
            __create(
                on: db,
                dtos: groups,
                label: "群组",
                errThrowing: .userInfoCreateFailed,
                modelBuilder: { $0.raw() },
                dtoBuilder: { DTO.Group<DTO.Queried>.make(from: $0) }
            )
        }
        
        public func delete(
            groupIds: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                UGroup.self,
                ids: groupIds,
                allSatisfy: allSatisfy,
                label: "用户群组",
                errThrowing: .groupDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ groupIds) }
            )
        }
        
        public func update(
            with updater: DTO.Group<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Group<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户群组",
                errThrowing: .groupUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.groupId) },
                dtoBuilder: { DTO.Group<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeSystem.GroupController {
    // MARK: - 加入群组
    
    func join(
        relations: [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .attach,
            label: "用户组与用户",
            errThrowing: .userJoinGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
    }
    
    // MARK: - 移出群组
    
    func kick(
        relations: [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        __manyToMany(
            relations,
            action: .detach,
            label: "用户组与用户",
            errThrowing: .userKickGroupFailed,
            siblingBuilder: { $0.model.$groups },
            modelsBuilder: { $0.eventLoop.makeSucceededResult($1.map { $0.model }) }
        )
    }
}

public extension PrivilegeSystem.GroupController {
    // MARK: - 加入群组
    
    func join(
        @MTMRelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        join(relations: content())
    }
    
    // MARK: - 移出群组
    
    func kick(
        @MTMRelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        kick(relations: content())
    }
}

public extension PrivilegeSystem.GroupController {
    func query(
        relations: [DTO.UserInGroupRelation<DTO.Prepare>]
    ) -> EventLoopRes<[DTO.UserInGroupRelation<DTO.Queried>], PrivilegeSystem.Errcase> {
        __query(on: db, relations: relations)
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
        relations: [DTO.UserInGroupRelation<DTO.Prepare>]
    ) -> EventLoopRes<[UserGroupPivot], PrivilegeSystem.Errcase> {
        UserGroupPivot.query(on: db)
            .filter(\.$primaryModel.$id ~~ relations.map { $0.user.id })
            .filter(\.$secondaryModel.$id ~~ relations.map { $0.group.id })
            .all()
            .withError(PrivilegeSystem.Errcase.userGroupRelationQueryFailed, "数据库查询时出错", category: .internal)
            .flatMapThrowing
        { rs throws(PrivilegeSystem.Errcase.ErrType) in
            guard rs.count == relations.count else {
                throw PrivilegeSystem.Errcase.userGroupRelationQueryFailed.d("所查到的关系数量与提供的不符", category: .external)
            }
            return rs
        }
    }
}
