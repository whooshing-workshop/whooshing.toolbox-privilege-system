import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import PrivilegeModule
import Collections
import LoggingAdvanced
import ResourceMacros
import Logging
@preconcurrency import AnyCodable

extension PrivilegeSystem {
    public final class Arbitrator: SystemOPAController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        package let opa: OPA
        
        public let logger: Logger
        
        let roleController: RoleController
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            opa: OPA,
            roleController: RoleController,
            logger: Logger
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.opa = opa
            self.roleController = roleController
            self.logger = logger
        }
        
        public func judge(
            moduleId: UUID,
            user: DTO.User<DTO.Queried>,
            role: DTO.Role<DTO.Queried>,
            resource: AnyResourceDTO,
            operation: AnyOperation,
            privilegeIds: [UUID]
        ) -> EventLoopRes<Result, Errcase> {
            let logger = getActionLogger()
            
            logger.info("执行 权限仲裁 操作", metadata: [
                "moduleId": .stringConvertible(moduleId.shortString),
                "user": .summaryData(user),
                "role": .summaryData(role),
                "operation": .summaryData(operation),
                "resource:": .summaryData(resource)
            ])
            logger.debug("操作参数", metadata: [
                "user": .data(user),
                "role": .data(role),
                "resource": .data(resource),
                "privilegeIds": .array(privilegeIds.map { .init(stringLiteral: $0.shortString) })
            ])
            
            // 检查所提供的 role 是否是 user 可用的身份，否则报错
            let roleCheck = roleController.is(role: role, appointedTo: user).flatMap {
                $0 ?
                self.db.eventLoop.makeSucceededResult(()) :
                self.db.eventLoop.makeFailedResult(Errcase.arbitrationDataCollectFailed, "所提供的 Role 并非对 User 可用", category: .external)
            }
            
            // 查询用户所在的群组，父群组的所有域权限
            let groupDomainPolicies: EventLoopRes<[DomainData], Errcase> = user.model.$groups.query(on: self.db)
                .with(\.$supers) { path in
                    path.with(\.$ancestor)
                }
                .all()
                .withError(Errcase.arbitrationDataCollectFailed, "取得用户所加入的所有群组失败", category: .internal)
                .flatMapThrowing
            { groups throws(Errcase.ErrType) in
                let gs = [UGroup]((
                    groups +
                    groups.flatMap { $0.supers.map { $0.ancestor } }
                ).uniqued())
                
                let ids = try required(throws: Errcase.arbitrateFailed, "取得群组 ID 失败", category: .internal) {
                    try gs.compactMap { try $0.requireID() }
                }
                
                return (gs, ids)
            }.flatMap { groups, groupIds in
                guard !groupIds.isEmpty else {
                    return self.db.eventLoop.makeSucceededResult([])
                }
                
                return DomainGroupPivot.query(on: self.db)
                    .filter(\.$secondaryModel.$id ~~ groupIds) // groups
                    .with(\.$primaryModel)  // domains
                    .all()
                    .withError(Errcase.arbitrationDataCollectFailed, "取得 Domain Pivot 数据失败", category: .internal)
                    .flatMapThrowing
                { pivots throws(Errcase.ErrType) in
                    try required(throws: Errcase.arbitrationDataCollectFailed, "取得 Domain 数据失败", category: .internal) {
                        // 内存装配：此时每一行 pivot 都天然维护了 [Group -> Domain] 的纽带关系
                        try pivots.map { pivot in
                            // 从最开始传入的 groups 内存集合里，凭借 pivot 的 groupId 瞬间定位到完整的 UGroup 实体
                            guard let associatedGroup = groups.first(where: { $0.id == pivot.$secondaryModel.id }) else {
                                throw Errcase.arbitrationDataCollectFailed.d("群组数据映射丢失", category: .internal)
                            }
                            
                            return DomainData(
                                domainId: try pivot.primaryModel.requireID(),
                                resource: resource.data,
                                operation: operation.rawValue,
                                user: user,
                                group: try .make(from: associatedGroup).get()
                            )
                        }
                    }
                }
            }
            
            // 查询用户本身被赋予的域权限
            let userDomainPolicies: EventLoopRes<[DomainData], Errcase> = user.model.$domains.get(on: self.db)
                .withError(Errcase.arbitrationDataCollectFailed, "数据库加载用户域权限失败", category: .internal)
                .flatMapThrowing
            { domains throws(Errcase.ErrType) in
                try required(throws: Errcase.arbitrationDataCollectFailed, "取得 Domain 数据失败", category: .internal) {
                    try domains.map { domain in
                        DomainData(
                            domainId: try domain.requireID(),
                            resource: resource.data,
                            operation: operation.rawValue,
                            user: user,
                            group: nil
                        )
                    }
                }
            }
            
            return roleCheck.flatMap {
                // 查询该用户所有的域权限，包括其所在的群组，父群组的所有域权限，及其本身被赋予的域权限
                [groupDomainPolicies, userDomainPolicies]
                    .flatten(on: self.db.eventLoop)
                    .flatMap
                { domainDatas in
                    self.__judge(
                        input: ArbitrateData(
                            moduleId: moduleId,
                            domains: domainDatas.flatMap { $0 },
                            role: .init(
                                roleId: role.id,
                                resource: resource.data,
                                operation: operation.rawValue,
                                user: user
                            ),
                            privileges: privilegeIds.map {
                                .init(
                                    privilegeId: $0,
                                    resource: resource.data,
                                    operation: operation.rawValue,
                                    user: user
                                )
                            }
                        ), logger: logger
                    )
                }
            }.map { res in
                logger.info("权限仲裁 操作执行成功", metadata: ["result": .summaryData(res)])
                logger.debug("仲裁结果", metadata: ["result": .data(res)])
                return res
            }.logIfFail(logger: logger, metadata: [
                "user": .data(user),
                "role": .data(role),
                "resource": .data(resource),
                "privilegeIds": .array(privilegeIds.map { .init(stringLiteral: $0.shortString) })
            ])
        }
        
        func __judge(
            input: ArbitrateData,
            logger: Logger
        ) -> EventLoopRes<Result, Errcase> {
            // 取得用户身份的 policy
            ([
                eventLoop.submitResult { () throws(Errcase.ErrType) in
                    let id = UUID()
                    logger.debug("进行 Role 仲裁", metadata: ["role": .data(input.role), "arbitrate-id": .stringConvertible(id)])
                    return id
                }.flatMap { id in
                    self.opa.query.data(
                        from: "/rules" + policyPath(moduleId: input.moduleId, modelId: input.role.roleId, type: Role.self, format: .path) + "/allow",
                        input: input.role,
                        as: RoleData.self,
                        to: Bool.self
                    ).errCast(Errcase.arbitrateFailed, "OPA Query 用户身份 失败", category: .internal)
                    .map { res in
                        logger.debug("Role 仲裁结果", metadata: ["result": .data(res), "arbitrate-id": .stringConvertible(id)])
                        return (Result.IdKey(type: .role, moduleId: input.moduleId, id: input.role.roleId), res)
                    }
                }
            // 取得所有域权限的 policy
            ] + input.domains.map { domainData in
                eventLoop.submitResult { () throws(Errcase.ErrType) in
                    let id = UUID()
                    logger.debug("进行 Domain 仲裁", metadata: ["domain": .data(domainData), "arbitrate-id": .stringConvertible(id)])
                    return id
                }.flatMap { id in
                    self.opa.query.data(
                        from: "/rules" + policyPath(moduleId: input.moduleId, modelId: domainData.domainId, type: Domain.self, format: .path) + "/allow",
                        input: domainData,
                        as: DomainData.self,
                        to: Bool.self
                    )
                    .errCast(Errcase.arbitrateFailed, "OPA Query 域权限 失败", category: .internal)
                    .map { res in
                        logger.debug("Domain 仲裁结果", metadata: ["result": .data(res), "arbitrate-id": .stringConvertible(id)])
                        return (Result.IdKey(type: .domain, moduleId: input.moduleId, id: domainData.domainId), res)
                    }
                }
            // 取得资源权限的 policy
            } + input.privileges.map { privilegeData in
                eventLoop.submitResult { () throws(Errcase.ErrType) in
                    let id = UUID()
                    logger.debug("进行 Privilege 仲裁", metadata: ["privilege": .data(privilegeData), "arbitrate-id": .stringConvertible(id)])
                    return id
                }.flatMap { id in
                    self.opa.query.data(
                        from: "/rules" + policyPath(moduleId: input.moduleId, modelId: privilegeData.privilegeId, type: "privilege", format: .path) + "/allow",
                        input: privilegeData,
                        as: PrivilegeData.self,
                        to: Bool.self
                    )
                    .errCast(Errcase.arbitrateFailed, "OPA Query 资源权限 失败", category: .internal)
                    .map { res in
                        logger.debug("Privilege 仲裁结果", metadata: ["result": .data(res), "arbitrate-id": .stringConvertible(id)])
                        return (Result.IdKey(type: .privilege, moduleId: input.moduleId, id: privilegeData.privilegeId), res)
                    }
                }
            })
            
            // 并行执行所有的权限判断
            .flatten(on: eventLoop).flatMap { (res: [(Result.IdKey, OPA.Answer<Bool?>)]) in
                var result = Result(result: true, reports: [:])
                for (k, r) in res {
                    guard let r = r.result else {
                        return self.eventLoop.makeFailedResult(Errcase.arbitrateFailed, "OPA 查询异常，Path 路径未找到", category: .internal)
                    }
                    result.and(result: r)
                    result.append(id: k, value: r)
                }
                return self.eventLoop.makeSucceededResult(result)
            }
        }
    }
}

extension PrivilegeSystem.Arbitrator {
    public struct Result: Sendable, CustomStringConvertible, Loggerable {
        public struct IdKey: Sendable, Hashable {
            public enum T: Sendable, Hashable {
                case role
                case domain
                case privilege
            }
            public let type: T
            public let moduleId: UUID
            public let id: UUID
        }
        
        public private(set) var result: Bool
        public private(set) var reports: OrderedDictionary<IdKey, Bool>
        
        mutating func and(result: Bool) {
            self.result = self.result && result
        }
        
        mutating func append(id: IdKey, value: Bool) {
            self.reports[id] = value
        }
        
        public var description: String {
            __logDescription(summary: false)
        }
        
        public var summaryDescription: String {
            __logDescription(summary: true)
        }
        
        func __logDescription(summary: Bool) -> String {
            var res = ""
            
            for (k, v) in reports {
                let path = switch k.type {
                case .role: policyPath(moduleId: k.moduleId, modelId: k.id, type: Role.self, format: .path)
                case .domain: policyPath(moduleId: k.moduleId, modelId: k.id, type: Domain.self, format: .path)
                case .privilege: policyPath(moduleId: k.moduleId, modelId: k.id, type: "privilege", format: .path)
                }
                
                if summary {
                    res += "\(path): \(v) | "
                } else {
                    res += "- \(path): \(v)\n"
                }
            }
            
            if summary {
                res += "\(result)"
            } else {
                res += "----------------------\n"
                res += "\(result)\n"
            }
            
            return res
        }
    }
    
    struct ArbitrateData: Encodable, Sendable, CustomStringConvertible, Loggerable {
        let moduleId: UUID
        let domains: [DomainData]
        let role: RoleData
        let privileges: [PrivilegeData]
        
        var description: String {
            formatQuery([
                "moduleId": AnyCodable(moduleId),
                "domains": AnyCodable(domains),
                "role": AnyCodable(role),
                "privileges": AnyCodable(privileges)
            ])
        }
    }
    
    struct RoleData: Encodable, Sendable, CustomStringConvertible, Loggerable {
        let roleId: UUID
        let resource: [String: AnyCodable]
        let operation: String
        let user: DTO.User<DTO.Queried>
        
        var description: String {
            formatQuery([
                "roleId": AnyCodable(roleId),
                "resource": AnyCodable(resource),
                "operation": AnyCodable(operation),
                "user": AnyCodable(user)
            ])
        }
    }
    
    struct DomainData: Encodable, Sendable, CustomStringConvertible, Loggerable {
        let domainId: UUID
        let resource: [String: AnyCodable]
        let operation: String
        let user: DTO.User<DTO.Queried>
        let group: DTO.Group<DTO.Queried>?
        
        var description: String {
            formatQuery([
                "domainId": AnyCodable(domainId),
                "resource": AnyCodable(resource),
                "operation": AnyCodable(operation),
                "user": AnyCodable(user),
                "group": AnyCodable(group)
            ])
        }
    }
    
    struct PrivilegeData: Encodable, Sendable, CustomStringConvertible, Loggerable {
        let privilegeId: UUID
        let resource: [String: AnyCodable]
        let operation: String
        let user: DTO.User<DTO.Queried>
        
        var description: String {
            formatQuery([
                "privilegeId": AnyCodable(privilegeId),
                "resource": AnyCodable(resource),
                "operation": AnyCodable(operation),
                "user": AnyCodable(user)
            ])
        }
    }
}
