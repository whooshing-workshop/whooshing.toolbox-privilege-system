import Fluent
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced

extension PrivilegeSystem {
    public struct UserInfoController: Controller {
        let db: PrivilegeSystem.PGDatabase
        let eventLoop: EventLoop
        
        init(system: PrivilegeSystem) {
            self.db = system.db
            self.eventLoop = system.eventLoop
        }
    }
    
    // MARK: - 增
    
    public func create(
        infos: [DTO.UserInfo<DTO.Prepare>]
    ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], Errcase> {
        
        let raws = infos.map { $0.raw() }
        
        return db.trans { db in
            raws.create(on: db)
                .withError(Errcase.userInfoAddFailed, category: .internel)
                .flatMap
            {
                let tasks: [EventLoopRes<DTO.UserInfo<DTO.Queried>, Errcase>] = raws.enumerated().map { i, raw in
                    eventLoop.submitResult { () throws(Errcase.ErrType) in
                        let infoId = try required(throws: Errcase.userInfoAddFailed, "获取用户信息 ID 失败", category: .internel) {
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
                            .withError(Errcase.userInfoAddFailed, "用户地址插入失败", category: .internel)
                            .map { @Sendable in info }
                    }.flatMap { info in
                        info.altMails
                            .create(on: db)
                            .withError(Errcase.userInfoAddFailed, "用户次选邮箱插入失败", category: .internel)
                            .map { @Sendable in info }
                    }.flatMap { info in
                        info.phones
                            .create(on: db)
                            .withError(Errcase.userInfoAddFailed, "用户手机号码插入失败", category: .internel)
                            .map { @Sendable in info }
                    }.flatMapThrowing { info throws(Errcase.ErrType) in
                        try DTO.UserInfo<DTO.Queried>.make(
                            from: raw,
                            addresses: info.addresses,
                            alternateEmails: info.altMails,
                            phones: info.phones
                        ).get()
                    }
                }
                
                return tasks.map{ $0.wrapped }
                    .flatten(on: eventLoop)
                    .withError(Errcase.userInfoAddFailed, "执行用户信息插入任务时失败", category: .internel)
            }
        }
        
        struct ExtendedInfos: Sendable {
            let addresses: [User.Info.Extended<User.Info.Address>]
            let altMails: [User.Info.Extended<User.Info.AlternateEmail>]
            let phones: [User.Info.Extended<User.Info.Phone>]
        }
        
        @Sendable
        func getRaws<T: DTO.UserInfoModel & __UserInfoModel>(
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
            .withError(Errcase.userInfoAddFailed, "用户信息插入失败", category: .internel)
            .flatMapThrowing
        { () throws(Errcase.ErrType) in
            try required(throws: Errcase.userInfoAddFailed, "整理用户信息插入结果时出错", category: .internel) {
                try raws.map {
                    try .make(from: $0, addresses: [], alternateEmails: [], phones: []).get()
                }
            }
        }
    }
    
    public func add(
        addresses: [DTO.UserExtendedInfo<DTO.Address, DTO.Prepare>],
        to userInfoId: UUID
    ) -> EventLoopRes<[DTO.UserExtendedInfo<DTO.Address, DTO.Queried>], Errcase> {
        let raws = addresses.map { $0.raw(for: userInfoId) }
        return raws
            .create(on: db)
            .withError(Errcase.userInfoAddFailed, "用户地址插入失败", category: .internel)
            .flatMapThrowing
        { () throws(Errcase.ErrType) in
            try required(throws: Errcase.userInfoAddFailed, "整理地址插入结果时出错", category: .internel) {
                try raws.map {
                    try .make(from: $0).get()
                }
            }
        }
    }
    
    public func add(
        alternateEmail: [DTO.UserExtendedInfo<DTO.AlternateEmail, DTO.Prepare>],
        to userInfoId: UUID
    ) -> EventLoopRes<[DTO.UserExtendedInfo<DTO.AlternateEmail, DTO.Queried>], Errcase> {
        let raws = alternateEmail.map { $0.raw(for: userInfoId) }
        return raws
            .create(on: db)
            .withError(Errcase.userInfoAddFailed, "用户次选邮箱插入失败", category: .internel)
            .flatMapThrowing
        { () throws(Errcase.ErrType) in
            try required(throws: Errcase.userInfoAddFailed, "整理次选邮箱插入结果时出错", category: .internel) {
                try raws.map {
                    try .make(from: $0).get()
                }
            }
        }
    }
    
    public func add(
        phones: [DTO.UserExtendedInfo<DTO.Phone, DTO.Prepare>],
        to userInfoId: UUID
    ) -> EventLoopRes<[DTO.UserExtendedInfo<DTO.Phone, DTO.Queried>], Errcase> {
        let raws = phones.map { $0.raw(for: userInfoId) }
        return raws
            .create(on: db)
            .withError(Errcase.userInfoAddFailed, "用户手机号码插入失败", category: .internel)
            .flatMapThrowing
        { () throws(Errcase.ErrType) in
            try required(throws: Errcase.userInfoAddFailed, "整理手机号码插入结果时出错", category: .internel) {
                try raws.map {
                    try .make(from: $0).get()
                }
            }
        }
    }
    
    // MARK: - 删
    
    public func delete(
        infoIds: [UUID]
    ) -> EventLoopRes<Void, Errcase> {
        db.trans { db in
            User.Info.query(on: db)
                .field(\.$id)
                .filter(\.$id ~~ infoIds)
                .all()
                .withError(Errcase.userInfoDeleteFailed, "查询用户信息 ID 时出错", category: .internel)
                .flatMapThrowing
            { info throws(Errcase.ErrType) in
                guard info.count == infoIds.count else {
                    throw Errcase.userInfoDeleteFailed.d("所提供的 ID 中有不存在项", category: .external)
                }
            }.flatMap {
                User.Info.query(on: db)
                    .filter(\.$id ~~ infoIds)
                    .delete()
                    .withError(Errcase.userInfoDeleteFailed, category: .internel)
            }
        }
    }
    
    public func delete(
        addresses: [UUID: [UUID]]
    ) -> EventLoopRes<Void, Errcase> {
        return db.trans { db in
            whereCondition(builder: User.Info.Extended<User.Info.Address>
                    .query(on: db)
                    .field(\.$id)
                )
                .all()
                .withError(Errcase.userInfoDeleteFailed, "查询用户信息地址 ID 时出错", category: .internel)
                .flatMapThrowing
            { info throws(Errcase.ErrType) in
                guard info.count == addresses.count else {
                    throw Errcase.userInfoDeleteFailed.d("所提供的 ID 中有不存在项", category: .external)
                }
            }.flatMap {
                whereCondition(builder: User.Info.Extended<User.Info.Address>.query(on: db))
                    .delete()
                    .withError(Errcase.userInfoDeleteFailed, category: .internel)
            }
        }
        
        @Sendable
        func whereCondition(
            builder: QueryBuilder<User.Info.Extended<User.Info.Address>>
        ) -> QueryBuilder<User.Info.Extended<User.Info.Address>> {
            builder.group(.or) { or in
                for (infoId, ids) in addresses {
                    or.group(.and) { and in
                        and.filter(\.$id ~~ ids)
                        and.filter(\.$userInfo.$id == infoId)
                    }
                }
            }
        }
    }
    
    public func delete(
        alternateEmails: [UUID: [UUID]]
    ) -> EventLoopRes<Void, Errcase> {
        return db.trans { db in
            whereCondition(builder: User.Info.Extended<User.Info.Address>
                    .query(on: db)
                    .field(\.$id)
                )
                .all()
                .withError(Errcase.userInfoDeleteFailed, "查询用户信息次选邮箱 ID 时出错", category: .internel)
                .flatMapThrowing
            { info throws(Errcase.ErrType) in
                guard info.count == alternateEmails.count else {
                    throw Errcase.userInfoDeleteFailed.d("所提供的 ID 中有不存在项", category: .external)
                }
            }.flatMap {
                whereCondition(builder: User.Info.Extended<User.Info.Address>.query(on: db))
                    .delete()
                    .withError(Errcase.userInfoDeleteFailed, category: .internel)
            }
        }
        
        @Sendable
        func whereCondition(
            builder: QueryBuilder<User.Info.Extended<User.Info.Address>>
        ) -> QueryBuilder<User.Info.Extended<User.Info.Address>> {
            builder.group(.or) { or in
                for (infoId, ids) in alternateEmails {
                    or.group(.and) { and in
                        and.filter(\.$id ~~ ids)
                        and.filter(\.$userInfo.$id == infoId)
                    }
                }
            }
        }
    }
    
    public func delete(
        phones: [UUID: [UUID]]
    ) -> EventLoopRes<Void, Errcase> {
        return db.trans { db in
            whereCondition(builder: User.Info.Extended<User.Info.Address>
                    .query(on: db)
                    .field(\.$id)
                )
                .all()
                .withError(Errcase.userInfoDeleteFailed, "查询用户信息手机号码 ID 时出错", category: .internel)
                .flatMapThrowing
            { info throws(Errcase.ErrType) in
                guard info.count == phones.count else {
                    throw Errcase.userInfoDeleteFailed.d("所提供的 ID 中有不存在项", category: .external)
                }
            }.flatMap {
                whereCondition(builder: User.Info.Extended<User.Info.Address>.query(on: db))
                    .delete()
                    .withError(Errcase.userInfoDeleteFailed, category: .internel)
            }
        }
        
        @Sendable
        func whereCondition(
            builder: QueryBuilder<User.Info.Extended<User.Info.Address>>
        ) -> QueryBuilder<User.Info.Extended<User.Info.Address>> {
            builder.group(.or) { or in
                for (infoId, ids) in phones {
                    or.group(.and) { and in
                        and.filter(\.$id ~~ ids)
                        and.filter(\.$userInfo.$id == infoId)
                    }
                }
            }
        }
    }
    
    // MARK: - 改
    
    public func update() {
        
    }
}
