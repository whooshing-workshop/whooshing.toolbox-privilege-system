import Fluent
import Censor
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    public struct GroupController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
        
        public func create(
            groups: [DTO.Group<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.Group<DTO.Queried>], Errcase> {
            db.trans { db in
                let gs = groups.map { $0.raw() }
                return gs
                    .create(on: db)
                    .withError(Errcase.groupCreateFailed, "创建群组时失败", category: .internal)
                    .flatMapThrowing
                { () throws(Errcase.ErrType) in
                    try gs.map { g throws(Errcase.ErrType) in
                        try required(throws: Errcase.groupCreateFailed, category: .internal) {
                            try DTO.Group<DTO.Queried>.make(from: g).get()
                        }
                    }
                }
            }
        }
        
        public func delete(
            groupIds: Set<UUID>,
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
            info updater: DTO.Group<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.Group<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户群组",
                errThrowing: .groupUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.groupId) },
                dtoBuilder: { DTO.Group<DTO.Queried>.make(from: $0) }
            )
        }
        
        public func join(
            @RelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .attach,
                label: "用户组与用户",
                errThrowing: .userJoinGroupFailed,
                siblingBuilder: { $0.model.$groups },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func kick(
            @RelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
            _ content: @Sendable @escaping () -> [Relation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
        ) -> EventLoopRes<Void, Errcase> {
            __manyToMany(
                content(),
                action: .detach,
                label: "用户组与用户",
                errThrowing: .userKickGroupFailed,
                siblingBuilder: { $0.model.$groups },
                modelsBuilder: { db.eventLoop.makeSucceededResult($0.map { $0.model }) }
            )
        }
        
        public func query(
            relations: [DTO.UserInGroupRelation<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.UserInGroupRelation<DTO.Queried>], Errcase> {
            __query(relations: relations)
                .flatMapThrowing
            { rs throws(Errcase.ErrType) in
                try required(throws: Errcase.userGroupRelationQueryFailed, category: .internal) {
                    try rs.map {
                        try .make(from: $0).get()
                    }
                }
            }
        }
        
        func __query(
            relations: [DTO.UserInGroupRelation<DTO.Prepare>]
        ) -> EventLoopRes<[UserGroupPivot], Errcase> {
            UserGroupPivot.query(on: db)
                .filter(\.$primaryModel.$id ~~ relations.map { $0.user.id })
                .filter(\.$secondaryModel.$id ~~ relations.map { $0.group.id })
                .all()
                .withError(Errcase.userGroupRelationQueryFailed, "数据库查询时出错", category: .internal)
                .flatMapThrowing
            { rs throws(Errcase.ErrType) in
                guard rs.count == relations.count else {
                    throw Errcase.userGroupRelationQueryFailed.d("所查到的关系数量与提供的不符", category: .external)
                }
                return rs
            }
        }
    }
}
