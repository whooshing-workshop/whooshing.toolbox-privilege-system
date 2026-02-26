import OPA
import ErrorHandle

extension PrivilegeModule {
    func opaInitialize() async throws {
        let policies = try await required(throws: Errcase.opaInitFailed, "取得资源权限数据失败", category: .internal) {
            try await Privilege.query(on: db).all().map {
                (
                    "/rules/\(moduleId)/privilege/\(try $0.requireID())",
                    $0.policy
                )
            }
        }
        
        for (path, policy) in policies {
            try await required(throws: Errcase.opaInitFailed, "OPA 注入权限数据失败", category: .internal) {
                _ = try await opa.policy.save(by: path, content: policy)
            }
        }
    }
}
