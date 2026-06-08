import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import ResourceMacros
import Logging

public extension PrivilegeModule {
    final class ResourceController: Controller {
        package typealias E = Errcase
        
        package let db: PGDatabase
        package let eventLoop: EventLoop
        
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
        
        public func create<T: Resource>(
            resources: [ResourceDTO<T, DTO.Prepare>]
        ) -> EventLoopRes<[ResourceDTO<T, DTO.Queried>], Errcase> {
            let logger = getActionLogger()
            logger.info("执行 创建资源 操作", metadata: ["resources": .summaryData(resources)])
            logger.debug("操作参数", metadata: ["resources": .data(resources)])
            return __create(
                on: db,
                dtos: resources,
                label: "资源",
                errThrowing: .resourceCreateFailed,
                modelBuilder: { $0.raw() },
                dtoBuilder: { ResourceDTO<T, DTO.Queried>.make(from: $0.fill()) }
            )
            .map { 
                logger.info("创建资源 操作成功", metadata: ["data": .summaryData($0)])
                logger.debug("创建资源 结果详细数据", metadata: ["data": .data($0)])
                return $0 
            }
            .logIfFail(logger: logger)
        }
        
        public func delete(
            ids: [UUID],
            allSatisfy: Bool = true
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 删除资源 操作", metadata: ["ids": .summaryData(ids)])
            logger.debug("操作参数", metadata: ["ids": .data(ids)])
            return __delete(
                on: db,
                AnyResource.self,
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
        
        public func update<T: Resource>(
            with updater: ResourceDTO<T, DTO.Prepare>.Updater
        ) -> EventLoopRes<ResourceDTO<T, DTO.Queried>, Errcase> {
            let logger = getActionLogger()
            logger.info("执行 更新资源 操作", metadata: ["data": .summaryData(updater)])
            logger.debug("更新资源 详细请求数据", metadata: ["data": .data(updater)])
            return __update(
                on: db,
                updater: updater,
                label: "资源",
                errThrowing: .resourceUpdateFailed,
                filterBuilder: { $0.filter(\.$id == updater.resourceId) },
                dtoBuilder: { ResourceDTO<T, DTO.Queried>.make(from: $0) }
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
