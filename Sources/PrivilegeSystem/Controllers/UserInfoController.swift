import Fluent
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import PrivilegeModule
import Logging

extension PrivilegeSystem {
    public final class UserInfoController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        let infoSliceController: InfoSliceController
        
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            infoSliceController: InfoSliceController,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.infoSliceController = infoSliceController
            self.logger = logger
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
            let logger = getActionLogger()
            logger.info("执行 删除用户信息 操作", metadata: ["infoIds": .summaryData(infoIds)])
            logger.debug("操作参数", metadata: ["infoIds": .data(infoIds)])
            return __delete(
                on: db,
                User.Info.self,
                ids: infoIds,
                allSatisfy: allSatisfy,
                label: "用户信息",
                errThrowing: .userInfoDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ infoIds) }
            )
            .map { _ in logger.info("删除用户信息 操作成功") }
            .logIfFail(logger: logger)
        }
        
        public func update(
            with updater: DTO.UserInfo<DTO.Prepare>.Updater
        ) -> EventLoopRes<DTO.UserInfo<DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新用户信息 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新用户信息 详细请求数据", metadata: ["data": .data(updater)])
            return __update(
                on: db,
                updater: updater,
                label: "用户信息",
                errThrowing: .userInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.userInfoId) },
                dtoBuilder: { DTO.UserInfo<DTO.Queried>.make(from: $0) }
            )
            .map { 
                logger.info("更新用户信息 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("更新用户信息 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
    }
}

public extension PrivilegeSystem.UserInfoController {
    func create(
        relations: [OTORelation<UUID, OTORelation<DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>>]
    ) -> EventLoopRes<Void, PrivilegeSystem.Errcase> {
        let logger = getActionLogger()
        logger.info("执行 创建用户信息 操作", metadata: ["relations": .summaryData(relations)])
        logger.debug("操作参数", metadata: ["relations": .data(relations)])
        return db.trans { db in
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
        .map { _ in logger.info("创建用户信息 操作成功") }
        .logIfFail(logger: logger)
    }
}
