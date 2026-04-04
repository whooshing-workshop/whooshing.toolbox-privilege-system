import Fluent
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule

extension PrivilegeSystem {
    public final class InfoSliceController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop
        ) {
            self.db = db
            self.eventLoop = eventLoop
        }
        
        public func create<T>(
            for infoId: UUID,
            extendedInfos: [DTO.InfoSlice<T, DTO.Prepare>]
        ) -> EventLoopRes<[DTO.InfoSlice<T, DTO.Queried>], Errcase> where T.Value == String {
            __create(on: db, for: infoId, extendedInfos: extendedInfos)
        }
        
        public func delete<T: DTO.UserInfoModel>(
            infoIds: [UUID],
            allSatisfy: Bool = true,
            type: T.Type = T.self
        ) -> EventLoopRes<Void, Errcase> {
            __delete(
                User.Info.Extended<T.Model>.self,
                ids: infoIds,
                allSatisfy: allSatisfy,
                label: "用户扩展信息",
                errThrowing: .userExtendedInfoDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ infoIds) }
            )
        }
        
        public func update<T>(
            with updater: DTO.InfoSlice<T, DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.InfoSlice<T, DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户扩展信息",
                errThrowing: .userExtendedInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.userInfoId) },
                dtoBuilder: { DTO.InfoSlice<T, DTO.Queried>.make(from: $0) }
            )
        }
        
        public func fetch(for userId: UUID) -> EventLoopRes<DTO.ExtendedInfo<DTO.Queried>, Errcase> {
            User.Info.query(on: db)
                .with(\.$addresses)
                .with(\.$alternateEmails)
                .with(\.$phones)
                .filter(\.$user.$id == userId)
                .first()
                .withError(Errcase.userExtendedInfoQueryFailed, category: .internal)
                .flatMapThrowing
            { info throws(Errcase.ErrType) in
                guard let i = info else {
                    throw Errcase.userExtendedInfoQueryFailed.d("用户信息不存在", category: .external)
                }
                
                return try required(throws: Errcase.userExtendedInfoQueryFailed, "用户信息转 DTO 失败", category: .internal) {
                    try DTO.ExtendedInfo<DTO.Queried>.init(
                        addresses: i.addresses.map { try .make(from: $0).get() },
                        alternateEmails: i.alternateEmails.map { try .make(from: $0).get() },
                        phones: i.phones.map { try .make(from: $0).get() }
                    )
                }
            }
        }
    }
}

extension PrivilegeSystem.InfoSliceController {
    func __create<T>(
        on db: PGDatabase,
        for infoId: UUID,
        extendedInfos: [DTO.InfoSlice<T, DTO.Prepare>]
    ) -> EventLoopRes<[DTO.InfoSlice<T, DTO.Queried>], PrivilegeSystem.Errcase> where T.Value == String {
        __create(
            on: db,
            dtos: extendedInfos,
            label: "用户扩展信息",
            errThrowing: .userExtendedInfoCreateFailed,
            modelBuilder: { $0.raw(for: infoId) },
            dtoBuilder: { DTO.InfoSlice<T, DTO.Queried>.make(from: $0) }
        )
    }
}
