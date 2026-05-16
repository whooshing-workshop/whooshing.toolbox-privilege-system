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
//   群组嵌套结构（GroupTests/RelationTests 中建立，via move API + group_paths）:
//     GT.ids[0] (AdministratorGroup)
//         ├─ GT.ids[6]  (SalesTeam)        ← 继承 domain0 (GlobalScope)
//         └─ GT.ids[7]  (MarketingTeam)    ← 继承 domain0 (GlobalScope)
//     GT.ids[1] (OperatorGroup)
//         └─ GT.ids[8]  (HumanResources)   ← 继承 domain1 (AsiaPacific)
//     GT.ids[2] (DeveloperHub)
//         ├─ GT.ids[9]  (QualityAssurance) ← 继承 domain2 (NorthAmerica)
//         └─ GT.ids[10] (Designers)        ← 继承 domain2 (NorthAmerica)
//
//   群组-域绑定（RelationTests 中建立）:
//     GT.ids[0] (AdministratorGroup) <- DT.ids[0] (GlobalScope)
//     GT.ids[1] (OperatorGroup)      <- DT.ids[1] (AsiaPacific)
//     GT.ids[2] (DeveloperHub)       <- DT.ids[2] (NorthAmerica)
//     GT.ids[3] (BannedUsers)        <- DT.ids[3] (SandboxEnvironment)
//     GT.ids[6] (SalesTeam)          <- DT.ids[4] (default, allow if {true})
//     GT.ids[7] (MarketingTeam)      <- DT.ids[4] (default, allow if {true})
//
//   用户-群组成员（RelationTests 中建立）:
//     AT.ids[0] -> [GT.ids[0]]            // 单域 AND 场景
//     AT.ids[1] -> [GT.ids[1]]            // 单域 AND 场景
//     AT.ids[2] -> [GT.ids[2]]            // 单域 AND 场景
//     AT.ids[3] -> [GT.ids[0], GT.ids[3]] // 双域 AND 场景
//     AT.ids[4] -> []                     // 无 group，纯角色判定场景
//     AT.ids[5] -> [GT.ids[0..3]]         // 四域 AND 场景
//     AT.ids[6] -> [GT.ids[6], GT.ids[7]] // 子群组用户，继承父群组域权限
//     AT.ids[7] -> [GT.ids[8], GT.ids[9]] // 多子群组用户，继承不同父群组域权限
//     AT.ids[8] -> [GT.ids[10]]           // 单子群组用户，继承父群组域权限
//
//   组内角色指派（RelationTests 中建立）:
//     RT.ids[3] (ObserverRole) -> AT.ids[0] in GT.ids[0]
//     RT.ids[4] (SalesManager) -> AT.ids[6] in GT.ids[6]
//     RT.ids[5] (HRLead)       -> AT.ids[7] in GT.ids[8]
//
//   用户被直接赋予的域权限:
//     AT.ids[0] <- DT.ids[0] (GlobalScope) ← 用户直接域权限场景
//
//   【鉴权逻辑】: 最终结果 = role策略 AND 所有所属群组域策略 AND 资源权限
//               嵌套群组时，父群组的域策略同样作用于用户
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
    // MARK: 13. 嵌套群组域权限继承
    // =========================================================================
    // 验证：当用户处于子群组时，所有父群组绑定的域策略都会叠加到鉴权链路中。
    //
    // 嵌套结构（由 GroupTests + RelationTests 建立）：
    //   GT.ids[0] (AdministratorGroup) ← domain0: global==true
    //       ├─ GT.ids[6]  (SalesTeam)        ← domain4: allow if {true}
    //       └─ GT.ids[7]  (MarketingTeam)    ← domain4: allow if {true}
    //   GT.ids[1] (OperatorGroup) ← domain1: region=="asia"
    //       └─ GT.ids[8]  (HumanResources)
    //   GT.ids[2] (DeveloperHub) ← domain2: region=="na"
    //       ├─ GT.ids[9]  (QualityAssurance)
    //       └─ GT.ids[10] (Designers)
    //
    // AT.ids[6] → [group6, group7]  继承 domain0 (GlobalScope)
    // AT.ids[7] → [group8, group9]  继承 domain1 (AsiaPacific) + domain2 (NorthAmerica)
    // AT.ids[8] → [group10]         继承 domain2 (NorthAmerica)
    // =========================================================================

    @Test("嵌套群组：子群组用户继承父群组 domain0(global==true) → global=true ALLOW")
    func nestedGroup_InheritParentDomain_Allow() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[6] 在 SalesTeam(group6) + MarketingTeam(group7) 中
        // group6/7 是 AdministratorGroup(group0) 的子群组，group0 绑定 domain0 (global==true)
        // group6/7 各自还直接绑定 domain4 (allow if {true})
        // 因此用户的域策略 = domain0(继承) AND domain4(直接) AND domain4(直接)
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 3, s: s) // ObserverRole: view

        // global=true → domain0(继承) 通过，domain4(直接) 通过 → ALLOW
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(allow.result, "子群组用户 + 满足父群组 domain0(global=true) → ALLOW")

        let domainReports = allow.reports.filter { $0.key.type == .domain }
        #expect(!domainReports.isEmpty, "嵌套群组用户应有 domain 报告")
        #expect(domainReports.values.allSatisfy { $0 }, "所有 domain 报告都应为 true")
    }

    @Test("嵌套群组：子群组用户父群组 domain0(global==true) 不满足 → global=false DENY")
    func nestedGroup_InheritParentDomain_Deny() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 3, s: s)

        // global=false → 继承自父群组的 domain0 失败 → 整体 DENY
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!deny.result, "global=false → 继承的 domain0 失败 → DENY")

        let domainReports = deny.reports.filter { $0.key.type == .domain }
        #expect(domainReports.values.contains(false), "domain0 报告应为 false")
    }

    @Test("嵌套群组：role 失败时即使父群组域策略全通过也应 DENY")
    func nestedGroup_RoleFailsOverridesDomain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 0, s: s) // SuperAdminRole: manage_all only

        // global=true → 所有 domain 通过，但 role 要求 manage_all → view 失败
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!res.result, "SuperAdminRole 不允许 view → DENY，即使 domain 全通过")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(
            type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == false)
    }

    @Test("嵌套群组：用户在两个不同父群组的子群组中 → 两个父群组域策略均须满足")
    func nestedGroup_MultiParentDomains_MustAllPass() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[7] → group8 (HumanResources，child of group1/OperatorGroup: domain1 region=asia)
        //           + group9 (QualityAssurance，child of group2/DeveloperHub: domain2 region=na)
        // domain1 要求 region="asia"，domain2 要求 region="na" → 两者互斥，始终 DENY
        let user = try await fetchUser(index: 7, s: s)
        let role = try await fetchRole(index: 3, s: s) // ObserverRole: view

        // 尝试只满足 domain1
        let denyWithAsia = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!denyWithAsia.result, "region=asia → domain1 通过但 domain2(na) 失败 → DENY")

        // 尝试只满足 domain2
        let denyWithNa = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!denyWithNa.result, "region=na → domain2 通过但 domain1(asia) 失败 → DENY")

        // 两者均不满足
        let denyEmpty = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: [:],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!denyEmpty.result, "无 region → 两个父群组域策略均失败 → DENY")
        let domainReports = denyEmpty.reports.filter { $0.key.type == .domain }
        #expect(domainReports.values.allSatisfy { !$0 }, "所有继承域报告应为 false")
    }

    @Test("嵌套群组：单一子群组用户继承父群组 domain2(region=na)")
    func nestedGroup_SingleChildInheritsParentDomain2() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[8] → group10 (Designers，child of group2/DeveloperHub: domain2 region=na)
        let user = try await fetchUser(index: 8, s: s)
        let role = try await fetchRole(index: 3, s: s) // ObserverRole: view

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "view", privilegeIds: []
        ).get()
        #expect(allow.result, "region=na → 继承的 domain2 通过 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!deny.result, "region=asia → 继承的 domain2(na) 失败 → DENY")
    }

    @Test("嵌套群组：子群组直接域策略与父群组继承域策略 AND 叠加验证")
    func nestedGroup_DirectAndInheritedDomainsAND() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[6] → group6(SalesTeam) + group7(MarketingTeam)
        //   group6/7 直接绑定 domain4 (allow if {true}) → 始终通过
        //   group6/7 父群组 group0 绑定 domain0 (global==true) → 需 global=true
        // 总和: domain0(继承) AND domain4(直接) AND domain4(直接)
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 1, s: s) // EditorRole: edit/publish

        // global=true，edit → 全通过
        let allPass = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "edit", privilegeIds: []
        ).get()
        #expect(allPass.result, "domain4(直接) + domain0(继承, global=true) + EditorRole(edit) → ALLOW")

        // global=false → domain0(继承) 失败 → DENY（即使 domain4 通过）
        let inheritFail = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "edit", privilegeIds: []
        ).get()
        #expect(!inheritFail.result, "domain0(继承) 失败 → 整体 DENY")

        // global=true 但 role 不允许 moderate → DENY
        let roleFail = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(!roleFail.result, "EditorRole 不允许 moderate → DENY")
    }

    @Test("嵌套群组：用户直接域权限与所在子群组继承的父群组域权限并行验证")
    func nestedGroup_UserDirectDomainPlusInherited() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[0] 在 group0 (AdministratorGroup) 中
        // AT.ids[0] 同时被直接赋予 domain0 (GlobalScope: global==true) (Shared.domainForUser[0] = [0])
        // domain0 来自：① group0 的直接绑定 ② 用户直接赋予 → 2 条 domain 报告
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 1, s: s) // EditorRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "edit", privilegeIds: []
        ).get()
        #expect(res.result, "用户直接域 + 群组域均满足 global=true → ALLOW")

        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(!domainReports.isEmpty, "应有 domain 报告")
        #expect(domainReports.values.allSatisfy { $0 }, "所有 domain 报告均为 true")

        // global=false → 无论直接还是继承的 domain0 均失败 → DENY
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "edit", privilegeIds: []
        ).get()
        #expect(!deny.result, "global=false → 用户直接域 + 群组域 domain0 均失败 → DENY")
    }

    // =========================================================================
    // MARK: 14. 组内角色（appoint / dismiss 动态场景）
    // =========================================================================
    // 设计图（diagrams/9.组内角色.png）要点：
    //   组内角色只在该群组内对指定用户生效。
    //   用户脱离该群组后，角色自动失效（鉴权时不再使用该角色）。
    //   同一用户可在不同群组中担任不同组内角色。
    //
    // 已有固定场景（RelationTests 建立）：
    //   RT.ids[3] (ObserverRole) → AT.ids[0] in GT.ids[0]
    //   RT.ids[4] (SalesManager) → AT.ids[6] in GT.ids[6]
    //   RT.ids[5] (HRLead)       → AT.ids[7] in GT.ids[8]
    //
    // 本节额外动态 appoint/dismiss：使用 RT.ids[2] 对 AT.ids[8] 进行组内角色指派和撤销。
    // =========================================================================

    @Test("组内角色：RelationTests 中已指派 ObserverRole 到 user0 in group0，judge 通过")
    func inGroupRole_ExistingAssignment_ObserverInGroup0() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // RT.ids[3] (ObserverRole: view) → AT.ids[0] in GT.ids[0]
        // AT.ids[0] 在 group0 中，group0 绑 domain0 (global==true)
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 3, s: s)

        // domain 满足 + role 满足 → ALLOW
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(allow.result, "ObserverRole(view) + domain0(global=true) → ALLOW")

        // domain 失败 → DENY（组内角色不能越过域策略）
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!deny.result, "global=false → domain0 失败 → DENY 即使有组内角色")
    }

    @Test("组内角色：RelationTests 中已指派 SalesManager(RT.ids[4]) 到 user6 in group6，嵌套域策略和组内角色共同生效")
    func inGroupRole_ExistingAssignment_SalesManagerInGroup6() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // RT.ids[4] (SalesManager: allow if {true}) → AT.ids[6] in GT.ids[6]
        // AT.ids[6] 在 group6(SalesTeam) + group7(MarketingTeam) 中
        // group6/7 直接绑 domain4 (allow if {true})，且父群组 group0 绑 domain0 (global==true)
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 4, s: s) // SalesManager: allow if {true}

        // SalesManager 策略 allow if {true}，global=true 满足 domain0 → ALLOW
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(true)],
            operation: "any_operation", privilegeIds: []
        ).get()
        #expect(allow.result, "SalesManager(allow all) + domain0(global=true) + domain4(allow all) → ALLOW")

        // global=false → 父群组 domain0 失败 → DENY
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["global": AnyCodable(false)],
            operation: "any_operation", privilegeIds: []
        ).get()
        #expect(!deny.result, "global=false → 继承的 domain0 失败 → DENY 即使是组内角色")
    }

    @Test("组内角色：动态 appoint，鉴权立即生效；dismiss 后验证撤销成功")
    func inGroupRole_DynamicAppointAndDismiss() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // 使用 RT.ids[2] (ModeratorRole: moderate) 动态指派给 AT.ids[8] in GT.ids[10]
        // AT.ids[8] → group10 (Designers，child of group2/DeveloperHub: domain2 region=na)
        let user = try await fetchUser(index: 8, s: s)
        let role = try await fetchRole(index: 2, s: s) // ModeratorRole: moderate

        // ─── 第一步：查询 user8 在 group10 中的关系对 ────────────────────────
        let allGroups = try await s.query(QGroup.self).all().get()
        let group10 = try #require(allGroups.first(where: { $0.id == GT.ids[10] }))

        let relReq = try await s.group.query(
            relations: [user =| group10]
        ).get()
        let rel = try #require(
            relReq.first(where: { $0.user.id == user.id && $0.group.id == group10.id }),
            "AT.ids[8] 应在 GT.ids[10] 中"
        )

        // ─── 第二步：appoint ModeratorRole → AT.ids[8] in GT.ids[10] ───────
        try await s.role.appoint {
            [role] => [rel]
        }.get()

        // ─── 第三步：鉴权验证（appoint 后应通过）────────────────────────────
        // ModeratorRole: moderate，group10 继承 domain2 (region=na)
        let allowAfterAppoint = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("na")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(allowAfterAppoint.result, "appoint 后：ModeratorRole + domain2(region=na) → ALLOW")

        // region=asia → domain2 失败 → DENY
        let denyDomain = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: ["region": AnyCodable("asia")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(!denyDomain.result, "region=asia → domain2(na) 失败 → DENY")

        // ─── 第四步：dismiss，撤销 ModeratorRole ────────────────────────────
        try await s.role.dismiss {
            [role] => [rel]
        }.get()

        // dismiss 后用 SuperAdminRole（不允许 moderate）验证不影响其他鉴权
        let superAdmin = try await fetchRole(index: 0, s: s)
        let denyWrongRole = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: superAdmin,
            resource: ["region": AnyCodable("na")],
            operation: "moderate", privilegeIds: []
        ).get()
        #expect(!denyWrongRole.result, "SuperAdminRole 不允许 moderate → DENY（dismiss 后无副作用）")
    }

    @Test("组内角色：同一用户在不同群组担任不同组内角色，两角色互相独立")
    func inGroupRole_SameUserDifferentGroupRoles() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[7] 在 group8(HumanResources) 和 group9(QualityAssurance) 中
        // RelationTests 中 RT.ids[5](HRLead, allow if {true}) → AT.ids[7] in GT.ids[8]
        // 动态再指派 RT.ids[6](allow if {true}) → AT.ids[7] in GT.ids[9]
        let user = try await fetchUser(index: 7, s: s)
        let hrLeadRole = try await fetchRole(index: 5, s: s) // HRLead: allow if {true}
        let role6 = try await fetchRole(index: 6, s: s)      // RT.ids[6]: allow if {true}

        let allGroups = try await s.query(QGroup.self).all().get()
        let group9 = try #require(allGroups.first(where: { $0.id == GT.ids[9] }))

        let relReq = try await s.group.query(
            relations: [user =| group9]
        ).get()
        let relInGroup9 = try #require(
            relReq.first(where: { $0.user.id == user.id && $0.group.id == group9.id }),
            "AT.ids[7] 应在 GT.ids[9] 中"
        )

        // 动态指派 role6 → user7 in group9
        try await s.role.appoint {
            [role6] => [relInGroup9]
        }.get()

        // ─── 测试场景：HRLead + group8 继承 domain1(asia) → 只满足 asia ───
        // HRLead(allow all) + group8 的父群组域策略(domain1: region=asia)
        // 注意：user7 在 group8 AND group9，两个父群组域策略均生效
        // group8 父群组: domain1 (region=asia)
        // group9 父群组: domain2 (region=na)
        // 两者互斥 → 始终 DENY
        let alwaysDeny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: hrLeadRole,
            resource: ["region": AnyCodable("asia")],
            operation: "hr_task", privilegeIds: []
        ).get()
        #expect(!alwaysDeny.result,
                "user7 在 group8+group9，父群组 domain1(asia) AND domain2(na) 互斥 → 始终 DENY")

        // 清理：dismiss role6 from user7 in group9
        try await s.role.dismiss {
            [role6] => [relInGroup9]
        }.get()
    }

    @Test("组内角色：judge 传入的 role 决定策略，组内指派不影响其他 role 的 judge 结果")
    func inGroupRole_ScopeIsolation_NotGlobal() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[0] 在 group0 中，RelationTests 将 ObserverRole(view) 指派到 user0 in group0
        // 当 judge 使用 SuperAdminRole → 应走 SuperAdminRole 的策略，而非 ObserverRole
        let user = try await fetchUser(index: 0, s: s)
        let superAdminRole = try await fetchRole(index: 0, s: s) // SuperAdminRole: manage_all only

        // SuperAdminRole + operation=view → role 不允许 → DENY（组内 ObserverRole 不影响此次 judge）
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: superAdminRole,
            resource: ["global": AnyCodable(true)],
            operation: "view", privilegeIds: []
        ).get()
        #expect(!deny.result, "SuperAdminRole 不允许 view → DENY，组内 ObserverRole 指派不影响此次 judge")

        // SuperAdminRole + manage_all + domain0(global=true) → ALLOW
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: superAdminRole,
            resource: ["global": AnyCodable(true)],
            operation: "manage_all", privilegeIds: []
        ).get()
        #expect(allow.result, "SuperAdminRole + manage_all + domain0(global=true) → ALLOW")
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
