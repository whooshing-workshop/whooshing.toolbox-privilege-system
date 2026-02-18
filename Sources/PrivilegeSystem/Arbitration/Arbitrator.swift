import Fluent
import Policy
import Vapor
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA

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
        
        func arbitrate(
            paths: [String],
            input: QueryData
        ) -> EventLoopRes<Bool, Errcase> {
            paths.map {
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
