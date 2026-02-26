import OPA
import Policy
import ErrorHandle

extension PrivilegeSystem {
    func opaInitialize() async throws(BscError<Errcase>) {
        let rolePolicies = try await required(throws: Errcase.opaInitFailed, "取得角色权限数据失败", category: .internal) {
            try await RolePolicy.query(on: db).all().map {
                (
                    policyPath(moduleId: $0.moduleId, modelId: $0.$parent.id, type: Role.self, format: .path),
                    $0.policy
                )
            }
        }
        
        let domainPolicies = try await required(throws: Errcase.opaInitFailed, "取得域权限数据失败", category: .internal) {
            try await DomainPolicy.query(on: db).all().map {
                (
                    policyPath(moduleId: $0.moduleId, modelId: $0.$parent.id, type: Domain.self, format: .path),
                    $0.policy
                )
            }
        }
        
        for (path, policy) in rolePolicies + domainPolicies {
            try await required(throws: Errcase.opaInitFailed, "OPA 注入权限数据失败", category: .internal) {
                _ = try await opa.policy.save(by: path, content: policy)
            }
        }
    }
}
