import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import PrivilegeModule
import Collections
@preconcurrency import AnyCodable

extension PrivilegeSystem {
    public final class Arbitrator: SystemOPAController {
        package let db: PGDatabase
        package let eventLoop: EventLoop
        package let opa: OPA
        
        init(
            db: PGDatabase,
            eventLoop: EventLoop,
            opa: OPA
        ) {
            self.db = db
            self.eventLoop = eventLoop
            self.opa = opa
        }
        
        public func judge(
            moduleId: UUID,
            user: DTO.User<DTO.Queried>,
            role: DTO.Role<DTO.Queried>,
            resource: [String: AnyCodable],
            operation: String,
            privilegeIds: [UUID]
        ) -> EventLoopRes<Result, Errcase> {
            user.model.groups.map { group in
                group.$domains.get(on: db)
                    .withError(Errcase.arbitrationDataCollectFailed, "数据库加载组域权限失败", category: .internal)
                    .flatMapThrowing
                { domains throws(Errcase.ErrType) in
                    try required(throws: Errcase.arbitrationDataCollectFailed, "取得 Domain 数据失败", category: .internal) {
                        try domains.map { domain in
                            DomainData(
                                domainId: try domain.requireID(),
                                resource: resource,
                                operation: operation,
                                user: user,
                                group: try .make(from: group).get()
                            )
                        }
                    }
                }
            }.flatten(on: eventLoop).flatMap { domainDatas in
                self.__judge(
                    input: ArbitrateData(
                        moduleId: moduleId,
                        domains: domainDatas.flatMap { $0 },
                        role: .init(
                            roleId: role.id,
                            resource: resource,
                            operation: operation,
                            user: user
                        ),
                        privileges: privilegeIds.map {
                            .init(
                                privilegeId: $0,
                                resource: resource,
                                operation: operation,
                                user: user
                            )
                        }
                    )
                )
            }
        }
        
        func __judge(
            input: ArbitrateData
        ) -> EventLoopRes<Result, Errcase> {
            ([
                opa.query.data(
                    from: policyPath(moduleId: input.moduleId, modelId: input.role.roleId, type: Role.self, format: .path),
                    input: input.role,
                    as: RoleData.self,
                    to: Bool.self
                )
                .errCast(Errcase.arbitrateFailed, "OPA Query 用户身份 失败", category: .internal)
                .map {
                    (Result.IdKey(type: .role, id: input.role.roleId), $0)
                }
            ] + input.domains.map { domainData in
                opa.query.data(
                    from: policyPath(moduleId: input.moduleId, modelId: domainData.domainId, type: Domain.self, format: .path),
                    input: domainData,
                    as: DomainData.self,
                    to: Bool.self
                )
                .errCast(Errcase.arbitrateFailed, "OPA Query 域权限 失败", category: .internal)
                .map { res in
                    (Result.IdKey(type: .domain, id: domainData.domainId), res)
                }
            } + input.privileges.map { privilegeData in
                opa.query.data(
                    from: policyPath(moduleId: input.moduleId, modelId: privilegeData.privilegeId, type: "privilege", format: .path),
                    input: privilegeData,
                    as: PrivilegeData.self,
                    to: Bool.self
                )
                .errCast(Errcase.arbitrateFailed, "OPA Query 资源权限 失败", category: .internal)
                .map { res in
                    (Result.IdKey(type: .domain, id: privilegeData.privilegeId), res)
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
    public struct Result: Sendable {
        public struct IdKey: Sendable, Hashable {
            public enum T: Sendable, Hashable {
                case role
                case domain
                case privilege
            }
            public let type: T
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
    }
    
    struct ArbitrateData: Encodable, Sendable {
        let moduleId: UUID
        let domains: [DomainData]
        let role: RoleData
        let privileges: [PrivilegeData]
    }
    
    struct RoleData: Encodable, Sendable {
        let roleId: UUID
        let resource: [String: AnyCodable]
        let operation: String
        let user: DTO.User<DTO.Queried>
    }
    
    struct DomainData: Encodable, Sendable {
        let domainId: UUID
        let resource: [String: AnyCodable]
        let operation: String
        let user: DTO.User<DTO.Queried>
        let group: DTO.Group<DTO.Queried>
    }
    
    struct PrivilegeData: Encodable, Sendable {
        let privilegeId: UUID
        let resource: [String: AnyCodable]
        let operation: String
        let user: DTO.User<DTO.Queried>
    }
}
