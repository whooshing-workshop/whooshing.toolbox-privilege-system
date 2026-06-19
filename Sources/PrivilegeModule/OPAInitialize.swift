import OPA
import Policy
import ErrorHandle
import Logging
import LoggingAdvanced

extension PrivilegeModule {
    func opaInitialize(logger: Logger) async throws(BscError<Errcase>) {
        let policies = try await logger.required(throws: Errcase.opaInitFailed, "从数据库查询资源权限数据失败", category: .internal) {
            try await __DBM.Privilege.query(on: db).all().map {
                (
                    policyPath(moduleId: moduleId, modelId: try $0.requireID(), type: __DBM.Privilege.self, format: .route),
                    $0.policy
                )
            }
        }
        
        for (path, policy) in policies {
            try await logger.required(throws: Errcase.opaInitFailed, "OPA 注入权限数据失败", category: .internal) {
                _ = try await opa.policy.save(by: path, content: assemblePolicy(path: path, policy: policy))
            }
        }
        
        logger.info("OPA 数据同步完成")
    }
}
