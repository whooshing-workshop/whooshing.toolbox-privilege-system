import Query
import Foundation
import PrivilegeModule

extension PrivilegeSystem {
    /// 用户附加切片信息控制器，提供对 `ExtendedInfo` 中的具体切片数据进行单独维护的能力。
    ///
    /// 用户的额外信息（如地址、备用邮箱、手机号等）往往会有多条，因此以独立的数据库实体存在，并由本控制器统一管理。
    /// 在常规流程下，一般通过 `UserInfoController` 创建用户主记录及其初始的切片信息，
    /// 本控制器则主要用于对已有用户的某个信息切片（如新增或删除一个电话号码）进行增删改查。
    public final class InfoSliceController: SystemController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
        /// 操作记录日志器。
        public let logger: Logger
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.logger = logger
        }
        
        /// 为特定用户信息添加一条或多条切片记录。
        ///
        /// 泛型 `T` 决定了这是添加哪种类型的信息（例如邮件、手机等）
        ///
        /// - Parameters:
        ///   - infoId: 目标 `UserInfo` 的记录 UUID。
        ///   - extendedInfos: 准备落库的一批信息切片对象（处于 `DTO.Prepare` 状态）。
        /// - Returns: `EventLoopRes<[QInfoSlice<T>], Errcase>`
        public func create<T>(
            for infoId: UUID,
            extendedInfos: OrderedSet<PInfoSlice<T>>,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<[QInfoSlice<T>], Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建用户扩展信息 操作", metadata: ["infoId": .stringConvertible(infoId), "extendedInfos": .summaryData(extendedInfos)])
            logger.debug("操作参数", metadata: ["extendedInfos": .data(extendedInfos)])
            let db = transactor?.db ?? self.db
            return __create(on: db, for: infoId, extendedInfos: extendedInfos)
                .map { 
                logger.info("创建用户扩展信息 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("创建用户扩展信息 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
                .logIfFail(logger: logger)
        }
        
        /// 删除特定信息切片。
        ///
        /// 通过提供泛型类型和 ID，可删除该类型的具体切片条目。
        /// - Parameters:
        ///   - infoIds: 要删除切片条目的 UUID。
        ///   - type: 显式指示你要删除哪个维度的扩展模型（如 `DTO.EmailInfo`）。
        /// - Returns: `EventLoopRes<Void, Errcase>`
        public func delete<T: UserInfoModel>(
            infoIds: OrderedSet<UUID>,
            type: T.Type = T.self,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除用户扩展信息 操作", metadata: ["infoIds": .summaryData(infoIds)])
            logger.debug("操作参数", metadata: ["infoIds": .data(infoIds)])
            let db = transactor?.db ?? self.db
            return __delete(
                on: db,
                QInfoSlice<T>.self,
                ids: infoIds,
                label: "用户扩展信息",
                errThrowing: .userExtendedInfoDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ infoIds) }
            )
            .map { _ in logger.info("删除用户扩展信息 操作成功") }
            .logIfFail(logger: logger)
        }
        
        /// 更新特定信息切片的详细数据。
        ///
        /// - Parameter updater: 特定切片的更新器对象 `PInfoSlice<T>.Updater`。
        /// - Returns: 更新完毕的实体对象 `QInfoSlice<T>`。
        public func update<T>(
            with updater: PInfoSlice<T>.Updater,
            on transactor: Transactor? = nil
        ) -> EventLoopRes<QInfoSlice<T>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新用户扩展信息 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新用户扩展信息 详细请求数据", metadata: ["data": .data(updater)])
            let db = transactor?.db ?? self.db
            return __update(
                on: db,
                updater: updater,
                label: "用户扩展信息",
                errThrowing: .userExtendedInfoUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.infoSliceId) },
                dtoBuilder: { QInfoSlice<T>.make(from: $0) }
            )
            .map { 
                logger.info("更新用户扩展信息 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("更新用户扩展信息 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
    }
}

extension PrivilegeSystem.InfoSliceController {
    func __create<T>(
        on db: PGDatabase,
        for infoId: UUID,
        extendedInfos: OrderedSet<PInfoSlice<T>>
    ) -> EventLoopRes<[QInfoSlice<T>], PrivilegeSystem.Errcase> {
        __create(
            on: db,
            dtos: extendedInfos,
            label: "用户扩展信息",
            errThrowing: .userExtendedInfoCreateFailed,
            modelBuilder: { .success($0.raw(for: infoId)) },
            dtoBuilder: { QInfoSlice<T>.make(from: $0) }
        )
    }
}
