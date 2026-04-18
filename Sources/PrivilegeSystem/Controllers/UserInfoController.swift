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
        let infoSliceController: InfoSliceController
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            infoSliceController: InfoSliceController
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.infoSliceController = infoSliceController
        }
        
        public func create(
            @OTOChainRelationBuilder<UUID, DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>
            _ content: @Sendable @escaping () -> [OTORelation<UUID, OTORelation<DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>>]
        ) -> EventLoopRes<Void, Errcase> {
            create(relations: content())
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
                filterBuilder: { $0.filter(\.$id == updater.userInfoId) },
                dtoBuilder: { DTO.UserInfo<DTO.Queried>.make(from: $0) }
            )
        }
    }
}

public extension PrivilegeSystem.UserInfoController {
    func create(
        relations: [OTORelation<UUID, OTORelation<DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        db.trans { db in
            let infos = relations.map { $0.right.left.raw(for: $0.left) }
            return infos
                .create(on: db)
                .withError(PrivilegeSystem.Errcase.userInfoCreateFailed, "数据库执行创建失败", category: .internal)
                .flatMap
            { _ in
                relations.enumerated().flatMap { (i, relation) in
                    [
                        self.infoSliceController.__create(
                            on: db,
                            for: try! infos[i].requireID(),
                            extendedInfos: relation.right.right.addresses
                        ).map { _ in },
                        
                        self.infoSliceController.__create(
                            on: db,
                            for: try! infos[i].requireID(),
                            extendedInfos: relation.right.right.alternateEmails
                        ).map { _ in },
                        
                        self.infoSliceController.__create(
                            on: db,
                            for: try! infos[i].requireID(),
                            extendedInfos: relation.right.right.phones
                        ).map { _ in }
                    ]
                }
                .flatten(on: db.eventLoop)
            }
        }
    }
}
