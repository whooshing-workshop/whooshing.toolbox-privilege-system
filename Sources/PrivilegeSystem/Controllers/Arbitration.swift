import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import PrivilegeModule
@preconcurrency import AnyCodable

extension PrivilegeSystem {
    public final class Arbitration: SystemOPAController {
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
        
        func arbitrate(
            policyPaths: [String],
            input: ForwardData
        ) -> EventLoopRes<Bool, Errcase> {
            policyPaths.map {
                opa.query.data(
                    from: $0,
                    input: input,
                    as: Bool.self
                ).errCast(Errcase.arbitrateFailed, "OPA Query 失败", category: .internal)
            }.flatten(on: eventLoop).flatMap { (res: [OPA.Answer<Bool?>]) in
                var result: Bool = true
                for r in res {
                    guard let r = r.result else {
                        return self.eventLoop.makeFailedResult(Errcase.arbitrateFailed, "OPA 查询异常，Path 路径未找到", category: .internal)
                    }
                    result = result && r
                }
                return self.eventLoop.makeSucceededResult(result)
            }
        }
    }
}

extension PrivilegeSystem.Arbitration {
    struct ForwardData: Encodable, Sendable {
        let resource: [String: AnyCodable]
        let action: String
        let user: DTO.User<DTO.Queried>
        let group: [String: AnyCodable]?
        
        init(
            resource: [String : AnyCodable],
            action: String,
            user: DTO.User<DTO.Queried>,
            group: [String : AnyCodable]? = nil
        ) {
            self.resource = resource
            self.action = action
            self.user = user
            self.group = group
        }
    }
}
