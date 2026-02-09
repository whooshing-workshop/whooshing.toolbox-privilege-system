import Fluent
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule

extension PrivilegeSystem {
    public final class UserInfoController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
        
        // MARK: - 增
        
        public func create(
            infos: [DTO.UserInfo<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], Errcase> {
            let raws = infos.map { $0.raw() }
            
            return db.trans { db in
                raws.create(on: db)
                    .withError(Errcase.userInfoAddFailed, category: .internal)
                    .flatMap
                {
                    let tasks: [EventLoopRes<DTO.UserInfo<DTO.Queried>, Errcase>] = raws.enumerated().map { i, raw in
                        self.eventLoop.submitResult { () throws(Errcase.ErrType) in
                            let infoId = try required(throws: Errcase.userInfoAddFailed, "获取用户信息 ID 失败", category: .internal) {
                                try raw.requireID()
                            }
                            return ExtendedInfos(
                                addresses: getRaws(userInfoId: infoId, dto: infos[i].addresses),
                                altMails: getRaws(userInfoId: infoId, dto: infos[i].alternateEmails),
                                phones: getRaws(userInfoId: infoId, dto: infos[i].phones)
                            )
                        }.flatMap { info in
                            info.addresses
                                .create(on: db)
                                .withError(Errcase.userInfoAddFailed, "用户地址插入失败", category: .internal)
                                .map { @Sendable in info }
                        }.flatMap { info in
                            info.altMails
                                .create(on: db)
                                .withError(Errcase.userInfoAddFailed, "用户次选邮箱插入失败", category: .internal)
                                .map { @Sendable in info }
                        }.flatMap { info in
                            info.phones
                                .create(on: db)
                                .withError(Errcase.userInfoAddFailed, "用户手机号码插入失败", category: .internal)
                                .map { @Sendable in info }
                        }.flatMapThrowing { info throws(Errcase.ErrType) in
                            try required(throws: Errcase.userInfoAddFailed, category: .internal) {
                                try DTO.UserInfo<DTO.Queried>.make(
                                    from: raw,
                                    addresses: info.addresses,
                                    alternateEmails: info.altMails,
                                    phones: info.phones
                                ).get()
                            }
                        }
                    }
                    
                    return tasks.map{ $0.wrapped }
                        .flatten(on: self.eventLoop)
                        .withError(Errcase.userInfoAddFailed, "执行用户信息插入任务时失败", category: .internal)
                }
            }
            
            struct ExtendedInfos: Sendable {
                let addresses: [User.Info.Extended<User.Info.Address>]
                let altMails: [User.Info.Extended<User.Info.AlternateEmail>]
                let phones: [User.Info.Extended<User.Info.Phone>]
            }
            
            @Sendable
            func getRaws<T: DTO.UserInfoModel>(
                userInfoId: User.Info.IDValue, dto: [DTO.UserExtendedInfo<T, DTO.Prepare>]
            ) -> [User.Info.Extended<T.Model>] where T.Value == String {
                dto.map { $0.raw(for: userInfoId) }
            }
        }
        
        public func add(
            infos: [DTO.UserInfo<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], Errcase> {
            let raws = infos.map { $0.raw() }
            return raws
                .create(on: db)
                .withError(Errcase.userInfoAddFailed, "用户信息插入失败", category: .internal)
                .flatMapThrowing
            { () throws(Errcase.ErrType) in
                try required(throws: Errcase.userInfoAddFailed, "整理用户信息插入结果时出错", category: .internal) {
                    try raws.map { i throws(Errcase.ErrType) in
                        try required(throws: Errcase.userInfoAddFailed, category: .internal) {
                            try .make(from: i, addresses: [], alternateEmails: [], phones: []).get()
                        }
                    }
                }
            }
        }
        
        public func add<T: DTO.UserInfoModel>(
            extendedInfos: [DTO.UserExtendedInfo<T, DTO.Prepare>],
            to userInfoId: UUID
        ) -> EventLoopRes<[DTO.UserExtendedInfo<T, DTO.Queried>], Errcase> where T.Value == String {
            let raws = extendedInfos.map { $0.raw(for: userInfoId) }
            return raws
                .create(on: db)
                .withError(Errcase.userInfoAddFailed, "用户\(T.description)插入失败", category: .internal)
                .flatMapThrowing
            { () throws(Errcase.ErrType) in
                try required(throws: Errcase.userInfoAddFailed, "整理\(T.description)插入结果时出错", category: .internal) {
                    try required(throws: Errcase.userInfoAddFailed, category: .internal) {
                        try raws.map {
                            try .make(from: $0).get()
                        }
                    }
                }
            }
        }
        
        // MARK: - 删
        
        public func delete(
            infoIds: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                User.Info.self,
                ids: infoIds,
                allSatisfy: allSatisfy,
                label: "用户信息",
                errThrowing: .userInfoDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ infoIds) }
            )
        }
        
        public func delete<T: DTO.UserInfoModel>(
            extendedType: T.Type = T.self,
            extendedInfos: [UUID: [UUID]],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            let allCounts = extendedInfos.values.reduce(0) { $0 + $1.count }
            
            guard !extendedInfos.isEmpty && allCounts > 0 else {
                return db.eventLoop.makeSucceededVoidResult()
            }
            
            return db.trans { db in
                let r: EventLoopRes<Void, Errcase>
                if allSatisfy {
                    r = whereCondition(
                        builder: User.Info.Extended<T.Model>
                            .query(on: db)
                            .field(\.$id)
                    )
                    .all()
                    .withError(Errcase.userInfoDeleteFailed, "查询用户\(T.description) ID 时出错", category: .internal)
                    .flatMapThrowing
                    { info throws(Errcase.ErrType) in
                        guard info.count == allCounts else {
                            throw Errcase.userInfoDeleteFailed.d("所提供的 ID 中有不存在项", category: .external)
                        }
                    }
                } else {
                    r = db.eventLoop.makeSucceededVoidResult()
                }
                
                return r.flatMap {
                    whereCondition(builder: User.Info.Extended<T.Model>.query(on: db))
                        .delete()
                        .withError(Errcase.userInfoDeleteFailed, category: .internal)
                }
            }
            
            @Sendable
            func whereCondition(
                builder: QueryBuilder<User.Info.Extended<T.Model>>
            ) -> QueryBuilder<User.Info.Extended<T.Model>> {
                builder.group(.or) { or in
                    for (infoId, ids) in extendedInfos {
                        or.group(.and) { and in
                            and.filter(\.$id ~~ ids)
                            and.filter(\.$userInfo.$id == infoId)
                        }
                    }
                }
            }
        }
        
        // MARK: - 改
        public func update(
            with updater: DTO.UserInfo<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.UserInfo<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户信息",
                errThrowing: .userInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.userId) },
                dtoBuilder: { DTO.UserInfo<DTO.Queried>.make(from: $0, addresses: $0.addresses, alternateEmails: $0.alternateEmails, phones: $0.phones) }
            )
        }
        
        public func update<T>(
            extendedInfo updater: DTO.UserExtendedInfo<T, DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.UserExtendedInfo<T, DTO.Queried>, Errcase> where T.Value == String {
            __update(
                updater: updater,
                label: "用户额外信息",
                errThrowing: .userInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.userInfoId) },
                dtoBuilder: { DTO.UserExtendedInfo<T, DTO.Queried>.make(from: $0) }
            )
        }
        
        // MARK: - 查
        public func fetch(
            infoIds: [UUID]
        ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], Errcase> {
            User.Info.query(on: db)
                .filter(\.$id ~~ infoIds)
                .sort(.custom(SortingSQL(uuids: infoIds)))
                .all()
                .withError(Errcase.userInfoQueryFailed, "查询出错", category: .internal)
                .flatMapThrowing
            { infos throws(Errcase.ErrType) in
                try infos.map { i throws(Errcase.ErrType) in
                    try required(throws: Errcase.userInfoQueryFailed, category: .internal) {
                        try .make(from: i, addresses: i.addresses, alternateEmails: i.alternateEmails, phones: i.phones).get()
                    }
                }
            }
        }
        
        //    public func query(
        //        keywords: [String],
        //        paginate: (Int, Int),
        //        order: String
        //    ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], Errcase> {
        //
        //    }
    }
}
