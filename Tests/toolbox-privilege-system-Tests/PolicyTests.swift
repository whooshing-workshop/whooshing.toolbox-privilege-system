import Testing
import Foundation
@preconcurrency import AnyCodable
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Query
import Policy

/*
typealias PT = PolicyTesting

@Suite("权限策略 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct PolicyTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .policy {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    // ----------------------------------------------------
    // 测试 1：创建各类复杂的策略网络
    // ----------------------------------------------------
    @Test("创建策略网络")
    func createNetwork() async throws {
        let (s, m) = try await TestingShared.getSystem()
        
        let roles = try await s.query(QRole.self).all().get()
        let domains = try await s.query(QDomain.self).all().get()
        
        try #require(roles.count >= 4)
        try #require(domains.count >= 3)
        
        // --- 0. 先行清理：清理在前面测试（如 RoleTests/DomainTests）中生成的占位默认策略 ---
        let existingRolePolicies = try await PolicyExp<Role>.query(on: s.db).all().get()
        if !existingRolePolicies.isEmpty {
            _ = try await s.policy.delete(to: Role.self, policyIds: existingRolePolicies.map { try! $0.requireID() }).get()
        }
        
        let existingDomainPolicies = try await PolicyExp<Domain>.query(on: s.db).all().get()
        if !existingDomainPolicies.isEmpty {
            _ = try await s.policy.delete(to: Domain.self, policyIds: existingDomainPolicies.map { try! $0.requireID() }).get()
        }
        
        // 1. 直属/基础角色策略 (挂载给 SuperAdminRole -> roles[0])
        let basePolicy = PPolicy<Role>(moduleId: m.moduleId, policy: \"\"\"
        allow if {
            input.operation == "manage_users"
        }
        \"\"\")
        
        // 2. 域约束隔离策略 (挂载给 NorthAmerica -> domains[2])
        // 该策略要求资源所属的地区必须与域一致
        let domainPolicy = PPolicy<Domain>(moduleId: m.moduleId, policy: \"\"\"
        allow if {
            input.resource.region == "NA"
        }
        \"\"\")
        
        // 3. 组内角色策略 (挂载给 ObserverRole -> roles[3])
        let inGroupPolicy = PPolicy<Role>(moduleId: m.moduleId, policy: \"\"\"
        allow if {
            input.operation == "view_dashboards"
        }
        \"\"\")
        
        // 4. 复杂的高级 DB-Integrated 策略 (挂载给 EditorRole -> roles[1])
        // 测试回调 PostgreSQL 拉取用户所属的群组，不仅要拥有这个角色，还必须身处特定群组
        let complexSqlPolicy = PPolicy<Role>(moduleId: m.moduleId, policy: \"\"\"
        allow if {
            input.operation == "publish_content"
            user_groups := pg.groups(input.user)
            count([g | g := user_groups[_]; contains(g.name, "Operations")]) > 0
        }
        \"\"\")
        
        // 批量创建策略
        _ = try await s.policy.create(to: Role.self) {
            [basePolicy] => roles[0].id
            [inGroupPolicy] => roles[3].id
            [complexSqlPolicy] => roles[1].id
        }.get()
        
        _ = try await s.policy.create(to: Domain.self) {
            [domainPolicy] => domains[2].id
        }.get()
    }
    
    // ----------------------------------------------------
    // 测试 2：核心鉴权流程 - 基础角色判决
    // ----------------------------------------------------
    @Test("基础角色与单维鉴权")
    func judgeBasic() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all().get()
        let roles = try await s.query(QRole.self).all().get()
        
        let user0 = users[0]
        let superAdminRole = roles[0]
        
        // 验证正确的操作放行
        let res1 = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user0,
            role: superAdminRole,
            resource: [:],
            operation: "manage_users",
            privilegeIds: []
        ).get()
        
        #expect(res1.result, "预期的管理操作应当被允许")
        
        // 验证错误的操作被拒
        let res2 = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user0,
            role: superAdminRole,
            resource: [:],
            operation: "delete_db",
            privilegeIds: []
        ).get()
        
        #expect(!res2.result, "未授权的操作应当被拒绝")
    }
    
    // ----------------------------------------------------
    // 测试 3：复杂 SQL Callback 的策略执行
    // ----------------------------------------------------
    @Test("集成数据库查询的高级策略 (pg.groups 联动)")
    func judgeComplexSQL() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all().get()
        let roles = try await s.query(QRole.self).all().get()
        
        let user1 = users[1]
        let editorRole = roles[1] // 绑定了包含 pg.groups 调用的策略
        
        // 尝试执行由于 SQL Callback 涉及的 publish_content 操作
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user1,
            role: editorRole,
            resource: [:],
            operation: "publish_content",
            privilegeIds: []
        ).get()
        
        // 在这里，系统底层的 OPA 必须能够向 Postgres 顺利发起查询而不断联
        // 具体允许与否取决于测试数据，核心是保证 HTTP 与 DB 交互不崩溃且正常反序列化
        _ = res.result
    }
    
    // ----------------------------------------------------
    // 测试 4：策略动态覆盖更新
    // ----------------------------------------------------
    @Test("策略的动态覆盖与二次判定")
    func updatePolicyAndRejudge() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let roles = try await s.query(QRole.self).all().get()
        let users = try await s.query(QUser.self).all().get()
        let superAdminRole = roles[0]
        let user0 = users[0]
        
        let existingPolicies = try await PolicyExp<Role>.query(on: s.db)
            .filter(\PolicyExp<Role>.$parent.$id == superAdminRole.id)
            .all().get()
        
        try #require(existingPolicies.count > 0)
        let oldPolicy = existingPolicies[0]
        
        // 更新策略放开 delete_db
        let updatedPolicy = PPolicy<Role>(
            moduleId: oldPolicy.moduleId,
            policy: \"\"\"
            allow if {
                input.operation == "manage_users"
            }
            allow if {
                input.operation == "delete_db"
            }
            \"\"\"
        )
        let updater = DTO.Policy<Role, DTO.Prepare>.Updater(
            policyId: try! oldPolicy.requireID(),
            policy: updatedPolicy.policy
        )
        
        _ = try await s.policy.update(to: Role.self, with: updater).get()
        
        // 二次鉴权
        let res2 = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user0,
            role: superAdminRole,
            resource: [:],
            operation: "delete_db",
            privilegeIds: []
        ).get()
        
        #expect(res2.result, "策略更新后 OPA 应当立即实时生效，允许 delete_db 操作")
    }
    
    // ----------------------------------------------------
    // 测试 5：策略的删除与清理
    // ----------------------------------------------------
    @Test("级联删除策略")
    func deletePolicy() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let roles = try await s.query(QRole.self).all().get()
        
        let existingPolicies = try await PolicyExp<Role>.query(on: s.db)
            .filter(\PolicyExp<Role>.$parent.$id == roles[0].id)
            .all().get()
        
        try #require(existingPolicies.count > 0)
        
        _ = try await s.policy.delete(to: Role.self, policyIds: [try! existingPolicies[0].requireID()]).get()
        
        let afterPolicies = try await PolicyExp<Role>.query(on: s.db)
            .filter(\PolicyExp<Role>.$parent.$id == roles[0].id)
            .all().get()
        
        #expect(afterPolicies.isEmpty, "数据库与 OPA 内存中的策略应当被完全抹除")
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .end
    }
}
*/
