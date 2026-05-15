import Testing
import Foundation
@preconcurrency import AnyCodable
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Query
import Policy
import Fluent

typealias PT = PolicyTesting

// =============================================================================
// PolicyTests.swift
// =============================================================================
// 本测试套件覆盖 PrivilegeSystem 中所有与策略鉴权相关的核心场景。
//
// 【关键设计】: 所有模型均通过前置测试套件保存的静态 ID 数组查询，
//              不使用名称查询（避免 DB 排序不确定性导致 OPA path 不匹配）。
//   AT.ids[i] → users 数组中第 i 个用户的 UUID
//   GT.ids[i] → groups 数组中第 i 个群组的 UUID
//   RT.ids[i] → roles 数组中第 i 个角色的 UUID
//   DT.ids[i] → domains 数组中第 i 个域的 UUID
//
// 【测试环境布局】（来自 Shared.swift 映射表）
//
//   角色策略（RoleTests 中创建，按 RT.ids 顺序）:
//     RT.ids[0] = SuperAdminRole  : allow if { input.operation == "manage_all" }
//     RT.ids[1] = EditorRole      : allow if { input.operation == "edit" OR "publish" }
//     RT.ids[2] = ModeratorRole   : allow if { input.operation == "moderate" }
//     RT.ids[3] = ObserverRole    : allow if { input.operation == "view" }
//     RT.ids[4..13]               : allow if { true }  (默认放行)
//
//   域策略（DomainTests 中创建，按 DT.ids 顺序）:
//     DT.ids[0] = GlobalScope        : allow if { input.resource.global == true }
//     DT.ids[1] = AsiaPacific        : allow if { input.resource.region == "asia" }
//     DT.ids[2] = NorthAmerica       : allow if { input.resource.region == "na" }
//     DT.ids[3] = SandboxEnvironment : allow if { input.resource.env == "sandbox" }
//     DT.ids[4..13]                  : allow if { true }  (默认放行)
//
//   群组-域绑定（RelationTests 中建立）:
//     GT.ids[0] (AdministratorGroup) <- DT.ids[0] (GlobalScope)
//     GT.ids[1] (OperatorGroup)      <- DT.ids[1] (AsiaPacific)
//     GT.ids[2] (DeveloperHub)       <- DT.ids[2] (NorthAmerica)
//     GT.ids[3] (BannedUsers)        <- DT.ids[3] (SandboxEnvironment)
//
//   用户-群组成员（RelationTests 中建立）:
//     AT.ids[0] -> [GT.ids[0]]            // 单域 AND 场景
//     AT.ids[1] -> [GT.ids[1]]            // 单域 AND 场景
//     AT.ids[2] -> [GT.ids[2]]            // 单域 AND 场景
//     AT.ids[3] -> [GT.ids[0], GT.ids[3]] // 双域 AND 场景
//     AT.ids[4] -> []                     // 无 group，纯角色判定场景
//     AT.ids[5] -> [GT.ids[0..3]]         // 四域 AND 场景
//
//   组内角色指派（RelationTests 中建立）:
//     RT.ids[3] (ObserverRole) -> AT.ids[0] in GT.ids[0]
//
//   【鉴权逻辑】: 最终结果 = role策略 AND 所有所属群组域策略 AND 资源权限
//
// =============================================================================

@Suite("权限策略 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct PolicyTesting {

    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .policy {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    /// 通过 AT.ids[index] 精确查询用户，并 eager-load groups 关系。
    /// judge() 内部直接访问 user.model.groups（内存缓存），必须预加载。
    private func fetchUser(index: Int, s: PrivilegeSystem) async throws -> QUser {
        let model = try await User.query(on: s.db)
            .filter(\.$id == AT.ids[index])
            .with(\.$groups)
            .first()
            .get()
        return try QUser.make(from: try #require(model)).get()
    }

    /// 通过 RT.ids[index] 精确查询角色（策略写入 OPA 时用的就是这个 ID）。
    private func fetchRole(index: Int, s: PrivilegeSystem) async throws -> QRole {
        try #require(
            try await s.query(QRole.self)
                .filter(\.id == RT.ids[index])
                .first().get()
        )
    }

    /// 通过 DT.ids[index] 精确查询域。
    private func fetchDomain(index: Int, s: PrivilegeSystem) async throws -> QDomain {
        try #require(
            try await s.query(QDomain.self)
                .filter(\.id == DT.ids[index])
                .first().get()
        )
    }

    // =========================================================================
    // MARK: 2. createWithReturning 验证
    // =========================================================================

    @Test("createWithReturning 返回正确的 QPolicy 字典（Role 类型）")
    func createWithReturning_Role() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // 使用 RT.ids[13] (DevOpsEngineer)，先清理再创建
        let targetId = RT.ids[13]

        let existing = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == targetId).all().get()
        for p in existing {
            let qp = try QPolicy<Role>.make(from: p).get()
            try await s.policy.delete(from: Role.self, policy: qp => targetId).get()
        }

        let newPolicy = PPolicy<Role>(
            moduleId: m.moduleId,
            policy: "allow if { input.operation == \"devops\" }"
        )
        let returned = try await s.policy.createWithReturning(to: Role.self) {
            [newPolicy] => targetId
        }.get()

        let policies = try #require(returned[targetId], "返回字典中应有 targetId 对应的条目")
        #expect(policies.count == 1)
        #expect(policies[0].moduleId == m.moduleId)
        #expect(policies[0].policy.contains("devops"))

        // 清理
        for qp in policies {
            try await s.policy.delete(from: Role.self, policy: qp => targetId).get()
        }
        // 恢复默认策略
        let def = PPolicy<Role>(moduleId: m.moduleId, policy: "allow if { true }")
        try await s.policy.create(to: Role.self) { [def] => targetId }.get()
    }

    @Test("createWithReturning 返回正确的 QPolicy 字典（Domain 类型）")
    func createWithReturning_Domain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // 使用 DT.ids[13] (PartnerNetwork)
        let targetId = DT.ids[13]

        let existing = try await PolicyExp<Domain>.query(on: s.db)
            .filter(\.$parent.$id == targetId).all().get()
        for p in existing {
            let qp = try QPolicy<Domain>.make(from: p).get()
            try await s.policy.delete(from: Domain.self, policy: qp => targetId).get()
        }

        let newPolicy = PPolicy<Domain>(
            moduleId: m.moduleId,
            policy: "allow if { input.resource.partner == true }"
        )
        let returned = try await s.policy.createWithReturning(to: Domain.self) {
            [newPolicy] => targetId
        }.get()

        let policies = try #require(returned[targetId])
        #expect(policies.count == 1)
        #expect(policies[0].policy.contains("partner"))

        for qp in policies {
            try await s.policy.delete(from: Domain.self, policy: qp => targetId).get()
        }
        let def = PPolicy<Domain>(moduleId: m.moduleId, policy: "allow if { true }")
        try await s.policy.create(to: Domain.self) { [def] => targetId }.get()
    }

    // =========================================================================
    // MARK: 3. 纯角色判定（AT.ids[4] 无 group，无域策略叠加）
    // =========================================================================

    @Test("纯角色判定：SuperAdminRole 允许 manage_all")
    func judgeRoleOnly_SuperAdmin_Allowed() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[4] → 无 group（Shared.userInGroups[4] = []）
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 0, s: s) // RT.ids[0] = SuperAdminRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "manage_all", privilegeIds: []
        ).get()
        
        #expect(res.result, "SuperAdminRole + manage_all → ALLOW")
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(domainReports.isEmpty, "无 group 的用户应无 domain 报告")
    }

    @Test("纯角色判定：SuperAdminRole 拒绝非授权操作")
    func judgeRoleOnly_SuperAdmin_Denied() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 0, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "edit", privilegeIds: []
        ).get()

        #expect(!res.result, "SuperAdminRole 不允许 edit → DENY")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == false)
    }

    @Test("纯角色判定：EditorRole 允许 edit 和 publish，拒绝 manage_all")
    func judgeRoleOnly_Editor() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 1, s: s) // RT.ids[1] = EditorRole

        for op in ["edit", "publish"] {
            let res = try await s.arbitrator.judge(
                moduleId: m.moduleId, user: user, role: role,
                resource: [:], operation: op, privilegeIds: []
            ).get()
            #expect(res.result, "EditorRole + \(op) → ALLOW")
        }

        let denied = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "manage_all", privilegeIds: []
        ).get()
        #expect(!denied.result, "EditorRole 不允许 manage_all → DENY")
    }

    @Test("纯角色判定：ModeratorRole 允许 moderate，拒绝其他")
    func judgeRoleOnly_Moderator() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 2, s: s) // RT.ids[2] = ModeratorRole

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "moderate", privilegeIds: []
        ).get()
        #expect(allow.result, "ModeratorRole + moderate → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "edit", privilegeIds: []
        ).get()
        #expect(!deny.result, "ModeratorRole 不允许 edit → DENY")
    }

    @Test("纯角色判定：ObserverRole 允许 view，reports 结构验证")
    func judgeRoleOnly_Observer_ReportsStructure() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 3, s: s) // RT.ids[3] = ObserverRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "view", privilegeIds: []
        ).get()

        #expect(res.result, "ObserverRole + view → ALLOW")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == true, "role 报告应为 true")
        #expect(res.reports.filter { $0.key.type == .domain }.isEmpty)
    }


    // =========================================================================
    // MARK: 4. 角色 + 单域 AND（AT.ids[0] -> GT.ids[0] -> DT.ids[0]: global==true）
    // =========================================================================

    @Test("角色+单域：role ✓ domain ✓ → ALLOW")
    func judgeRoleAndDomain_BothPass() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)  // AT.ids[0] -> group0 -> domain0
        let role = try await fetchRole(index: 1, s: s)  // RT.ids[1] = EditorRole: edit/publish

        // operation=edit ✓, resource.global=true (domain0 通过) ✓ → ALLOW
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "edit", privilegeIds: []
        ).get()

        #expect(res.result, "EditorRole + domain0(global==true) + edit → ALLOW")
        #expect(res.reports.filter { $0.key.type == .role }.values.allSatisfy { $0 })
        #expect(res.reports.filter { $0.key.type == .domain }.values.allSatisfy { $0 })
    }

    @Test("角色+单域：role ✓ domain ✗ (global=false) → DENY")
    func judgeRoleAndDomain_DomainFails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 1, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "edit", privilegeIds: []
        ).get()

        #expect(!res.result, "domain0 要求 global==true，false 时 DENY")
        #expect(res.reports.filter { $0.key.type == .domain }.values.contains(false))
    }

    @Test("角色+单域：role ✗ (operation不匹配) domain ✓ → DENY")
    func judgeRoleAndDomain_RoleFails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)  // RT.ids[0] = SuperAdminRole: manage_all only

        // operation=edit → SuperAdminRole 不允许 → role 失败
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "edit", privilegeIds: []
        ).get()

        #expect(!res.result, "SuperAdminRole 不允许 edit，domain 通过也应 DENY")
        #expect(res.reports.filter { $0.key.type == .role }.values.contains(false))
    }

    @Test("角色+单域：role ✗ domain ✗ → DENY")
    func judgeRoleAndDomain_BothFail() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "delete", privilegeIds: []
        ).get()

        #expect(!res.result, "role 和 domain 均失败 → DENY")
    }

    // =========================================================================
    // MARK: 5. 不同单域策略验证
    // =========================================================================

    @Test("AsiaPacific域(DT.ids[1])：region=asia 时允许，region=na 时拒绝")
    func judgeAsiaPacificDomain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[1] -> GT.ids[1] -> DT.ids[1]: region=="asia"
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 3, s: s)  // ObserverRole: view

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "view", privilegeIds: []
        ).get()
        #expect(allow.result, "region=asia → AsiaPacific 域通过 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!deny.result, "region=na → AsiaPacific 域失败 → DENY")
    }

    @Test("NorthAmerica域(DT.ids[2])：region=na 时允许，region=asia 时拒绝")
    func judgeNorthAmericaDomain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[2] -> GT.ids[2] -> DT.ids[2]: region=="na"
        let user = try await fetchUser(index: 2, s: s)
        let role = try await fetchRole(index: 2, s: s)  // ModeratorRole: moderate

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(allow.result, "region=na → NorthAmerica 域通过 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(!deny.result, "region=asia → NorthAmerica 域失败 → DENY")
    }

    // =========================================================================
    // MARK: 6. 双域 AND（AT.ids[3] -> GT.ids[0]+GT.ids[3] -> domain0+domain3）
    // =========================================================================
    // domain0: global==true，domain3: env==sandbox
    // 两者均需满足，任一失败则整体 DENY

    @Test("双域AND：全部满足 → ALLOW，reports 包含 2 个域")
    func judgeMultiDomain_AllPass() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 3, s: s)  // ObserverRole: view

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true), "env": AnyCodable("sandbox")],
            operation: "view", privilegeIds: []
        ).get()

        #expect(res.result, "role+domain0+domain3 全通过 → ALLOW")
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(domainReports.count == 2, "应有 2 个域报告")
        #expect(domainReports.values.allSatisfy { $0 })
    }

    @Test("双域AND：domain3(env==sandbox)不满足 → DENY")
    func judgeMultiDomain_Domain3Fails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 3, s: s)

        // 只有 global=true，无 env → domain3 失败
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "view", privilegeIds: []
        ).get()

        #expect(!res.result, "domain3 要求 env==sandbox，缺失 → DENY")
        #expect(res.reports.filter { $0.key.type == .domain }.values.contains(false))
    }

    @Test("双域AND：domain0(global==true)不满足 → DENY")
    func judgeMultiDomain_Domain0Fails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 3, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["env": AnyCodable("sandbox")],
            operation: "view", privilegeIds: []
        ).get()

        #expect(!res.result, "domain0 要求 global==true，缺失 → DENY")
    }

    @Test("双域AND：两域均不满足 → DENY，两个域报告均为 false")
    func judgeMultiDomain_BothFail() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 3, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "view", privilegeIds: []
        ).get()

        #expect(!res.result, "两域均失败 → DENY")
        #expect(res.reports.filter { $0.key.type == .domain }.values.allSatisfy { !$0 })
    }

    // =========================================================================
    // MARK: 7. 四域极端 AND（AT.ids[5] -> domain0,1,2,3）
    // =========================================================================
    // domain1(asia) 和 domain2(na) 互斥，region 不能同时满足，验证 AND 严格性

    @Test("四域极端AND：domain1(asia)与domain2(na)互斥 → 始终 DENY")
    func judgeQuadDomain_AlwaysDeny() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[5] -> GT.ids[0,1,2,3] -> domain0,1,2,3
        let user = try await fetchUser(index: 5, s: s)
        let role = try await fetchRole(index: 3, s: s)

        // 尽量满足：global=true, env=sandbox, region=asia（但 domain2 需要 na）
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [
                "global": AnyCodable(true),
                "env": AnyCodable("sandbox"),
                "region": AnyCodable("asia")
            ],
            operation: "view", privilegeIds: []
        ).get()

        #expect(!res.result, "domain2 需要 region=na，与 domain1 的 asia 互斥 → 始终 DENY")
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(domainReports.count == 4, "4 个 group → 4 个域报告")
        #expect(domainReports.values.contains(false))
    }


    // =========================================================================
    // MARK: 8. 组内角色指派场景（RT.ids[3] -> AT.ids[0] in GT.ids[0]）
    // =========================================================================

    @Test("组内角色指派：ObserverRole + domain0(global==true) 满足 → ALLOW")
    func judgeInGroupRole_Allow() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[0] 在 GT.ids[0] 中，RT.ids[3](ObserverRole) 已通过 roleForGroupUser 指派
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 3, s: s)

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(allow.result, "ObserverRole + domain0 全满足 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!deny.result, "global=false → domain0 失败 → DENY")
    }

    @Test("组内角色指派：使用不匹配的 role → DENY（role 策略不通过）")
    func judgeInGroupRole_WrongRole() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)  // SuperAdminRole: manage_all only

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "edit", privilegeIds: []
        ).get()

        #expect(!res.result, "SuperAdminRole 不允许 edit，domain 通过也 DENY")
    }

    // =========================================================================
    // MARK: 9. 策略删除与重建（delete + create）
    // =========================================================================

    @Test("Role 策略删除：从 DB 移除，计数减少 1")
    func rolePolicy_DeleteAndVerify() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let targetId = RT.ids[12]  // ContentReviewer

        let before = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == targetId).all().get()
        guard let first = before.first else {
            Issue.record("RT.ids[12](ContentReviewer) 应有策略"); return
        }

        let qp = try QPolicy<Role>.make(from: first).get()
        try await s.policy.delete(from: Role.self, policy: qp => targetId).get()

        let after = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == targetId).count().get()
        #expect(after == before.count - 1, "删除后应少 1 条")

        // 恢复
        let def = PPolicy<Role>(moduleId: m.moduleId, policy: "allow if { true }")
        try await s.policy.create(to: Role.self) { [def] => targetId }.get()
        let restored = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == targetId).count().get()
        #expect(restored == before.count, "恢复后数量应与原来一致")
    }

    @Test("Role 策略替换：新语义立即生效（deploy 限制）")
    func rolePolicy_ReplaceAndRejudge() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let targetId = RT.ids[13]  // DevOpsEngineer，默认 allow if { true }
        // AT.ids[4]：无 group，纯角色判定
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 13, s: s)

        // 替换前：allow if { true } → 任何操作通过
        let before = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "anything", privilegeIds: []
        ).get()
        #expect(before.result, "替换前默认策略允许任何操作")

        // 删除旧策略
        let old = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == targetId).all().get()
        for p in old {
            let qp = try QPolicy<Role>.make(from: p).get()
            try await s.policy.delete(from: Role.self, policy: qp => targetId).get()
        }

        // 写入新策略：只允许 deploy
        let restricted = PPolicy<Role>(
            moduleId: m.moduleId,
            policy: "allow if { input.operation == \"deploy\" }"
        )
        try await s.policy.create(to: Role.self) { [restricted] => targetId }.get()

        // 验证新策略
        let deployRes = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "deploy", privilegeIds: []
        ).get()
        #expect(deployRes.result, "替换后：deploy → ALLOW")

        let denyRes = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "anything", privilegeIds: []
        ).get()
        #expect(!denyRes.result, "替换后：anything → DENY")

        // 清理并恢复
        let newPolicies = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == targetId).all().get()
        for p in newPolicies {
            let qp = try QPolicy<Role>.make(from: p).get()
            try await s.policy.delete(from: Role.self, policy: qp => targetId).get()
        }
        let def = PPolicy<Role>(moduleId: m.moduleId, policy: "allow if { true }")
        try await s.policy.create(to: Role.self) { [def] => targetId }.get()
    }

    @Test("Domain 策略删除并恢复")
    func domainPolicy_DeleteAndVerify() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let targetId = DT.ids[12]  // LegacySystem，默认 allow if { true }

        let before = try await PolicyExp<Domain>.query(on: s.db)
            .filter(\.$parent.$id == targetId).all().get()
        guard let first = before.first else {
            Issue.record("DT.ids[12](LegacySystem) 应有策略"); return
        }

        let qp = try QPolicy<Domain>.make(from: first).get()
        try await s.policy.delete(from: Domain.self, policy: qp => targetId).get()

        let after = try await PolicyExp<Domain>.query(on: s.db)
            .filter(\.$parent.$id == targetId).count().get()
        #expect(after == before.count - 1)

        let def = PPolicy<Domain>(moduleId: m.moduleId, policy: "allow if { true }")
        try await s.policy.create(to: Domain.self) { [def] => targetId }.get()
    }


    // =========================================================================
    // MARK: 10. 综合场景
    // =========================================================================

    @Test("综合：EditorRole + AsiaPacific域，正确地区可编辑，错误地区被拒")
    func comprehensive_EditorInAsiaPacific() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[1] -> GT.ids[1] -> DT.ids[1]: region=="asia"
        // RT.ids[1] = EditorRole：edit/publish
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 1, s: s)

        // ✓ 亚太地区 + edit
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "edit", privilegeIds: []
        ).get()
        #expect(allow.result, "EditorRole + region=asia → ALLOW")

        // ✗ 欧洲地区 + publish（region 不匹配 domain1）
        let denyRegion = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("eu")],
            operation: "publish", privilegeIds: []
        ).get()
        #expect(!denyRegion.result, "region=eu → AsiaPacific 域失败 → DENY")

        // ✗ 正确地区但无权操作
        let denyOp = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "manage_all", privilegeIds: []
        ).get()
        #expect(!denyOp.result, "EditorRole 不允许 manage_all → DENY")
    }

    @Test("综合：ModeratorRole + NorthAmerica域，跨域操作被隔离")
    func comprehensive_ModeratorInNorthAmerica() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[2] -> GT.ids[2] -> DT.ids[2]: region=="na"
        let user = try await fetchUser(index: 2, s: s)
        let role = try await fetchRole(index: 2, s: s)  // ModeratorRole: moderate

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(allow.result, "ModeratorRole + region=na → ALLOW")

        let denyAsia = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(!denyAsia.result, "region=asia → NorthAmerica 域失败 → DENY")

        let denyEdit = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "edit", privilegeIds: []
        ).get()
        #expect(!denyEdit.result, "ModeratorRole 不允许 edit → DENY")
    }

    @Test("综合：ObserverRole + GlobalScope+Sandbox 双域，精准访问控制矩阵")
    func comprehensive_ObserverTwoDomains() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[3] -> GT.ids[0](domain0: global==true) + GT.ids[3](domain3: env==sandbox)
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 3, s: s)  // ObserverRole: view

        struct Case {
            let resource: [String: AnyCodable]
            let op: String
            let expected: Bool
            let desc: String
        }

        let cases: [Case] = [
            .init(resource: ["global": AnyCodable(true), "env": AnyCodable("sandbox")],
                  op: "view", expected: true,   desc: "双域全满足 + view → ALLOW"),
            .init(resource: ["global": AnyCodable(true), "env": AnyCodable("sandbox")],
                  op: "manage_all", expected: false, desc: "role 不满足 manage_all → DENY"),
            .init(resource: ["global": AnyCodable(false), "env": AnyCodable("sandbox")],
                  op: "view", expected: false,  desc: "global=false → domain0 失败 → DENY"),
            .init(resource: ["global": AnyCodable(true)],
                  op: "view", expected: false,  desc: "env 缺失 → domain3 失败 → DENY"),
            .init(resource: [:], op: "view", expected: false, desc: "两域均失败 → DENY")
        ]

        for c in cases {
            let res = try await s.arbitrator.judge(
                moduleId: m.moduleId, user: user, role: role,
                resource: c.resource, operation: c.op, privilegeIds: []
            ).get()
            if res.result != c.expected {
                Issue.record("场景「\(c.desc)」期望 \(c.expected)，实际 \(res.result)")
            }
        }
    }

    // =========================================================================
    // MARK: 11. 边界场景
    // =========================================================================

    @Test("边界：空 privilegeIds 不影响纯角色鉴权")
    func edge_EmptyPrivilegeIds() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)  // 无 group
        let role = try await fetchRole(index: 1, s: s)  // EditorRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "edit", privilegeIds: []
        ).get()
        #expect(res.result, "空 privilegeIds 不影响纯角色鉴权")
    }

    @Test("边界：无 group 用户的 reports 中不含 domain 条目")
    func edge_NoGroupUser_NoDomainReports() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)  // Shared.userInGroups[4] = []
        let role = try await fetchRole(index: 3, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:], operation: "view", privilegeIds: []
        ).get()

        #expect(res.result)
        #expect(res.reports.filter { $0.key.type == .domain }.isEmpty,
                "无 group 的用户不应有 domain 报告")
    }

    @Test("边界：role 失败时 AND 逻辑使最终结果为 false")
    func edge_RoleFailsAndShortCircuit() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[0] 在 group0 中 (domain0 通过: global==true)，但 role 失败
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 2, s: s)  // ModeratorRole: moderate only

        // operation=view → ModeratorRole 不允许 → role 失败
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],  // domain0 通过
            operation: "view", privilegeIds: []
        ).get()

        #expect(!res.result, "role 失败（ModeratorRole 不含 view）→ DENY")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == false)
    }

    @Test("边界：默认域策略 allow if {true} 对所有 resource 放行")
    func edge_DefaultDomainAllowsAll() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[6] -> GT.ids[6,7]
        // Shared.domainForGroup: domain4(Europe) -> group6,7，默认 allow if {true}
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 3, s: s)  // ObserverRole: view

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:],  // 完全空的 resource
            operation: "view", privilegeIds: []
        ).get()

        #expect(res.result, "默认域策略 allow if {true} 对空 resource 应放行")
    }

    // =========================================================================
    // MARK: 12. 环境清理验证
    // =========================================================================

    @Test("清理验证：DevOpsEngineer(RT.ids[13]) 已恢复 1 条策略")
    func cleanup_DevOpsEngineer() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let count = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == RT.ids[13]).count().get()
        #expect(count == 1, "DevOpsEngineer 应恢复为 1 条策略，当前 \(count) 条")
    }

    @Test("清理验证：ContentReviewer(RT.ids[12]) 已恢复 1 条策略")
    func cleanup_ContentReviewer() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let count = try await PolicyExp<Role>.query(on: s.db)
            .filter(\.$parent.$id == RT.ids[12]).count().get()
        #expect(count == 1, "ContentReviewer 应恢复为 1 条策略，当前 \(count) 条")
    }

    @Test("清理验证：所有角色均至少有 1 条策略")
    func cleanup_AllRolesHavePolicies() async throws {
        let (s, _) = try await TestingShared.getSystem()
        for (i, roleId) in RT.ids.enumerated() {
            let count = try await PolicyExp<Role>.query(on: s.db)
                .filter(\.$parent.$id == roleId).count().get()
            if count < 1 {
                Issue.record("RT.ids[\(i)] 角色应至少有 1 条策略，当前 \(count) 条")
            }
        }
    }

    @Test("清理验证：所有域均至少有 1 条策略")
    func cleanup_AllDomainsHavePolicies() async throws {
        let (s, _) = try await TestingShared.getSystem()
        for (i, domainId) in DT.ids.enumerated() {
            let count = try await PolicyExp<Domain>.query(on: s.db)
                .filter(\.$parent.$id == domainId).count().get()
            if count < 1 {
                Issue.record("DT.ids[\(i)] 域应至少有 1 条策略，当前 \(count) 条")
            }
        }
    }

    // =========================================================================
    // MARK: 测试结束
    // =========================================================================

    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .end
    }
}
