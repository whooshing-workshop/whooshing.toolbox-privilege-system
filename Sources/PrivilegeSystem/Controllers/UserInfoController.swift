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
        let userExtendedInfoController: UserExtendedInfoController
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            userExtendedInfoController: UserExtendedInfoController
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.userExtendedInfoController = userExtendedInfoController
        }
        
        public struct Extended<T: DTO.Status>: Sendable {
            let addresses: [DTO.UserExtendedInfo<DTO.Address, T>]
            let alternateEmails: [DTO.UserExtendedInfo<DTO.AlternateEmail, T>]
            let phones: [DTO.UserExtendedInfo<DTO.Phone, T>]
        }
        
        public func create(
            for userId: UUID,
            @OTORelationBuilder<DTO.UserInfo<DTO.Prepare>, Extended<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [OTORelation<DTO.UserInfo<DTO.Prepare>, Extended<DTO.Prepare>>]
        ) -> EventLoopRes<Void, Errcase> {
            create(for: userId, relations: content())
        }
        
        public func create(
            for userId: UUID,
            infos: [DTO.UserInfo<DTO.Prepare>]
        ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], Errcase> {
            __create(on: db, for: userId, infos: infos)
        }
        
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
        
        public func update(
            with updater: DTO.UserInfo<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.UserInfo<DTO.Queried>, Errcase> {
            __update(
                updater: updater,
                label: "用户信息",
                errThrowing: .userInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.userId) },
                dtoBuilder: { DTO.UserInfo<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeSystem.UserInfoController {
    func create(
        for userId: UUID,
        relations: [OTORelation<DTO.UserInfo<DTO.Prepare>, Extended<DTO.Prepare>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        db.trans { db in
            self.__create(on: db, for: userId, infos: relations.map { $0.left }).flatMap { _ in
                relations.flatMap { relation in
                    [
                        self.userExtendedInfoController.__create(
                            on: db,
                            for: relation.left.id,
                            extendedInfos: relation.right.addresses
                        ).map { _ in },
                        
                        self.userExtendedInfoController.__create(
                            on: db,
                            for: relation.left.id,
                            extendedInfos: relation.right.alternateEmails
                        ).map { _ in },
                        
                        self.userExtendedInfoController.__create(
                            on: db,
                            for: relation.left.id,
                            extendedInfos: relation.right.phones
                        ).map { _ in }
                    ]
                }
                .flatten(on: db.eventLoop)
            }
        }
    }
}

extension PrivilegeSystem.UserInfoController {
    func __create(
        on db: PGDatabase,
        for userId: UUID,
        infos: [DTO.UserInfo<DTO.Prepare>]
    ) -> EventLoopRes<[DTO.UserInfo<DTO.Queried>], PrivilegeSystem.Errcase> {
        __create(
            on: db,
            dtos: infos,
            label: "用户信息",
            errThrowing: .userInfoCreateFailed,
            modelBuilder: { $0.raw(for: userId) },
            dtoBuilder: { DTO.UserInfo<DTO.Queried>.make(from: $0) }
        )
    }
}
