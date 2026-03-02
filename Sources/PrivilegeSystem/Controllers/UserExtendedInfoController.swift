import Fluent
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule

extension PrivilegeSystem {
    public final class UserExtendedInfoController: SystemController {
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
            extendedInfos: [DTO.UserExtendedInfo<T, DTO.Prepare>]
        ) -> EventLoopRes<[DTO.UserExtendedInfo<T, DTO.Queried>], Errcase> where T.Value == String {
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
            with updater: DTO.UserExtendedInfo<T, DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.UserExtendedInfo<T, DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户扩展信息",
                errThrowing: .userExtendedInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.userInfoId) },
                dtoBuilder: { DTO.UserExtendedInfo<T, DTO.Queried>.make(from: $0) }
            )
        }
    }
}

extension PrivilegeSystem.UserExtendedInfoController {
    func __create<T>(
        on db: PGDatabase,
        for infoId: UUID,
        extendedInfos: [DTO.UserExtendedInfo<T, DTO.Prepare>]
    ) -> EventLoopRes<[DTO.UserExtendedInfo<T, DTO.Queried>], PrivilegeSystem.Errcase> where T.Value == String {
        __create(
            on: db,
            dtos: extendedInfos,
            label: "用户扩展信息",
            errThrowing: .userExtendedInfoCreateFailed,
            modelBuilder: { $0.raw(for: infoId) },
            dtoBuilder: { DTO.UserExtendedInfo<T, DTO.Queried>.make(from: $0) }
        )
    }
}
