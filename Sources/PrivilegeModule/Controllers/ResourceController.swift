import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import ResourceMacros
import Logging

public extension PrivilegeModule {
    /// 资源控制器，管理当前权限模块辖下所有资源的生命周期（增删改）。
    ///
    /// 资源（`Resource`）泛指一切需要受 OPA 策略保护或仲裁访问权限的实体数据。
    /// 可以是一个文档、一个仪表盘、或者系统中的一台设备。
    ///
    /// - `create`: 将特定泛型类型的资源注册进权限控制系统。
    /// - `update`: 更新资源的属性内容。
    /// - `delete`: 根据资源的唯一 ID 从权限池中物理擦除它。
    final class ResourceController: Controller {
        package typealias E = Errcase
        
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
        
        /// 批量创建某种具体泛型类型的资源。
        ///
        /// 只有被成功创建并写入数据库的资源，才会获取到一个全局唯一的 ID，
        /// 这个 ID 是后续通过 OPA 进行鉴权的基石。
        ///
        /// - Parameter resources: 一组遵循 `Resource` 协议的具体资源对象（例如 `FileResource`）。
        /// - Returns: 返回落库完毕、包含 ID 字段的 `QResource<T>` 数组。
        ///
        /// ```swift
        /// let docResource = JsonResource(
        ///     name: "Secret_Doc",
        ///     content: ["isPrivate": AnyCodable(true)]
        /// )
        /// let resourceDTO = try await module.resource.create(resources: [docResource]).first!
        /// ```
        public func create<T: Resource>(
            resources: [T]
        ) -> EventLoopRes<[QResource<T>], Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建资源 操作", metadata: ["resources": .summaryData(resources)])
            logger.debug("操作参数", metadata: ["resources": .data(resources)])
            return __create(
                on: db,
                dtos: resources,
                label: "资源",
                errThrowing: .resourceCreateFailed,
                modelBuilder: { .success(__DBM.ResourceModel<T>(from: $0)) },
                dtoBuilder: { QResource<T>.make(from: $0.fill()) }
            )
            .map { 
                logger.info("创建资源 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("创建资源 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
        
        /// 根据 ID 批量删除资源。
        ///
        /// 当一个资源不再存在时，所有依附其上的 OPA 策略和权限指派均将失效。
        ///
        /// - Parameters:
        ///   - ids: 资源的 UUID 列表。
        ///   - allSatisfy: 是否必须要求所有提供的 ID 均成功删除。若为 `true`，只要其中有一个 ID 不存在，操作就会被回滚并抛出异常。
        /// - Returns: `EventLoopRes<Void, Errcase>`
        public func delete(
            ids: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除资源 操作", metadata: ["ids": .summaryData(ids)])
            logger.debug("操作参数", metadata: ["ids": .data(ids)])
            return __delete(
                on: db,
                __SDBM.AnyResource.self,
                ids: ids,
                allSatisfy: allSatisfy,
                label: "资源",
                errThrowing: .resourceDeleteFailed,
                fieldBuilder: { $0.field(\.$id) },
                filterBuilder: { $0.filter(\.$id ~~ ids) }
            )
            .map { logger.info("删除资源 操作成功") }
            .logIfFail(logger: logger)
        }
        
        /// 更新资源的元信息。
        ///
        /// 使用 `Updater` 对象可以指定性地更新资源名称、资源原始数据体等内容。
        ///
        /// - Parameter updater: `ResourceDTO<T, DTO.Prepare>.Updater` 更新执行器。
        /// - Returns: `ResourceDTO<T, DTO.Queried>`
        public func update<T: Resource>(
            with updater: QResource<T>.Updater
        ) -> EventLoopRes<QResource<T>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新资源 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新资源 详细请求数据", metadata: ["data": .data(updater)])
            return __update(
                on: db,
                updater: updater,
                label: "资源",
                errThrowing: .resourceUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.resourceId) },
                dtoBuilder: { QResource<T>.make(from: $0) }
            )
            .map { 
                logger.info("更新资源 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("更新资源 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
    }
}
