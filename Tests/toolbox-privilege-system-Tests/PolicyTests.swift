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
//     AT.ids[3] -> [GT.ids[0], GT.ids[3]] // 双群组域 + 用户直接域 AND 场景
//     AT.ids[4] -> []                     // 无 group，但有用户直接域
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
//     AT.ids[0] <- DT.ids[0] (GlobalScope)
//     AT.ids[3] <- DT.ids[4] (Europe, default allow)
//     AT.ids[4] <- DT.ids[6] + DT.ids[7] (default allow)
//     AT.ids[5] <- DT.ids[8] + DT.ids[9] (default allow)
//
//   【鉴权逻辑】: judge() 先要求传入 role 对 user 可用；
//               最终结果 = role策略 AND 所属/父群组域策略 AND 用户直接域策略 AND 资源权限
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

    // =========================================================================
    // MARK: 3. 纯角色判定（AT.ids[4] 可用角色验证）
    // =========================================================================
    // user4 直接用户角色 = [RT[6], RT[7]]（均为 allow if {true}）
    // user4 直接用户域 = [domain6, domain7]（均为 allow if {true}）
    // userInGroups[4] = []（无 group）
    // 注意：user4 虽无 group，但有直接赋予的用户域，judge 时 domain reports 不为空！
    // 命名角色（SuperAdmin/Editor/Moderator/Observer）在 MARK 4-5 中与域策略一同验证

    
    // user: 4
    // role: 6      nil
    // group: nil   nil
    // domain:  6   nil
    //          7   nil
    // resource: nil
    @Test("纯角色判定：user4+RT[6]，role 通过，user 直接域(domain6/domain7)也通过")
    func judgeRoleOnly_User4_Allow() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user4: 直接用户角色 RT[6]/RT[7]，直接用户域 domain6/domain7
        // domain6/domain7 均为 allow if {true}，空 resource 也能通过
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 6, s: s) // RT[6]: allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .anything, privilegeIds: []
        ).get()

        #expect(res.result, "RT[6](allow all) + domain6/7(allow all) → ALLOW")
        // user4 有直接赋予的 domain6, domain7，所以有 domain 报告
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(!domainReports.isEmpty, "user4 有直接赋予的 domain6/domain7，应有 domain 报告")
        #expect(domainReports.count == 2, "domain6 和 domain7 共 2 个 domain 报告")
        #expect(domainReports.values.allSatisfy { $0 }, "domain6/domain7 均 allow if {true} → 全 true")
    }

    @Test("纯角色判定：user4 使用 RT[7]，reports 结构验证（含用户直接域）")
    func judgeRoleOnly_User4_ReportsStructure() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user4: 直接用户角色 RT[6]/RT[7]，直接用户域 domain6/domain7
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 7, s: s) // RT[7]: allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "RT[7](allow all) + domain6/7(allow all) → ALLOW")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == true, "role 报告应为 true")
        // user4 有直接赋予的 domain6, domain7，无 group
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(domainReports.count == 2, "user4 有 domain6 和 domain7 共 2 个直接域报告")
    }

    // SuperAdminRole 完整验证：user0 持有 RT[0]（用户角色），在 group0 中（domain0: global==true）
    @Test("纯角色判定：SuperAdminRole(user0) manage_all+global=true → ALLOW")
    func judgeRoleOnly_SuperAdmin_Allowed() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user0 可用角色: RT[0](SuperAdmin 用户角色), RT[3](Observer 组内角色 in group0)
        // user0 在 group0，group0 绑 domain0(global==true)，需配合 global=true 使域通过
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s) // RT[0] = SuperAdminRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .manage_all, privilegeIds: []
        ).get()
        #expect(res.result, "SuperAdminRole + manage_all + domain0(global=true) → ALLOW")
    }

    @Test("纯角色判定：SuperAdminRole(user0) edit → DENY（role 策略不匹配）")
    func judgeRoleOnly_SuperAdmin_Denied() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .edit, privilegeIds: []
        ).get()
        #expect(!res.result, "SuperAdminRole 不允许 edit → DENY")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == false)
    }

    // EditorRole 完整验证：user1 持有 RT[1]（用户角色），在 group1 中（domain1: region==asia）
    @Test("纯角色判定：EditorRole(user1) edit+region=asia → ALLOW；manage_all → DENY")
    func judgeRoleOnly_Editor() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user1 可用角色: RT[1](Editor), RT[3](Observer)；在 group1，domain1(region=asia)
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 1, s: s) // RT[1] = EditorRole

        for op in ["edit", "publish"] {
            let res = try await s.arbitrator.judge(
                moduleId: m.moduleId, user: user, role: role,
                resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
                operation: JsonOperation(rawValue: op)!, privilegeIds: []
            ).get()
            #expect(res.result, "EditorRole + \(op) + region=asia → ALLOW")
        }

        let denied = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .manage_all, privilegeIds: []
        ).get()
        #expect(!denied.result, "EditorRole 不允许 manage_all → DENY")
    }

    // ModeratorRole 完整验证：user2 持有 RT[2]，在 group2 中（domain2: region==na）
    @Test("纯角色判定：ModeratorRole(user2) moderate+region=na → ALLOW；edit → DENY")
    func judgeRoleOnly_Moderator() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user2 可用角色: RT[2](Moderator)；在 group2，domain2(region=na)
        let user = try await fetchUser(index: 2, s: s)
        let role = try await fetchRole(index: 2, s: s)

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(allow.result, "ModeratorRole + moderate + region=na → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .edit, privilegeIds: []
        ).get()
        #expect(!deny.result, "ModeratorRole 不允许 edit → DENY")
    }

    // ObserverRole 完整验证：user1 持有 RT[3]（用户角色），在 group1（domain1: region==asia）
    @Test("纯角色判定：ObserverRole(user1) view+region=asia → ALLOW，reports 结构验证")
    func judgeRoleOnly_Observer_ReportsStructure() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user1 可用角色: RT[1](Editor), RT[3](Observer)
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 3, s: s) // RT[3] = ObserverRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "ObserverRole + view + region=asia → ALLOW")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == true, "role 报告应为 true")
    }


    // =========================================================================
    // MARK: 4. 角色 + 单域 AND（AT.ids[0] -> GT.ids[0] -> DT.ids[0]: global==true）
    // =========================================================================

    // user0 可用角色：RT[0](SuperAdmin 用户角色) + RT[3](Observer 组内角色 in group0)
    // group0 绑 domain0: global==true

    @Test("角色+单域：role(Observer) ✓ domain ✓ → ALLOW")
    func judgeRoleAndDomain_BothPass() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user0 → group0 → domain0(global==true)；RT[3](Observer) 是 user0 的组内角色
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 3, s: s) // RT[3] = ObserverRole: view

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "ObserverRole + domain0(global=true) + view → ALLOW")
        #expect(res.reports.filter { $0.key.type == .role }.values.allSatisfy { $0 })
        #expect(res.reports.filter { $0.key.type == .domain }.values.allSatisfy { $0 })
    }

    @Test("角色+单域：role(Observer) ✓ domain ✗ (global=false) → DENY")
    func judgeRoleAndDomain_DomainFails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 3, s: s) // RT[3] ObserverRole

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "domain0 要求 global==true，false 时 DENY")
        #expect(res.reports.filter { $0.key.type == .domain }.values.contains(false))
    }

    @Test("角色+单域：role(SuperAdmin) ✗ (operation不匹配) domain ✓ → DENY")
    func judgeRoleAndDomain_RoleFails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s) // RT[0] = SuperAdminRole: manage_all only

        // operation=view → SuperAdminRole 不允许 → role 失败；domain0(global=true) 通过
        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "SuperAdminRole 不允许 view，domain 通过也应 DENY")
        #expect(res.reports.filter { $0.key.type == .role }.values.contains(false))
    }

    @Test("角色+单域：role(SuperAdmin) ✗ domain ✗ → DENY")
    func judgeRoleAndDomain_BothFail() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "role(SuperAdmin+view) 和 domain(global=false) 均失败 → DENY")
    }

    // =========================================================================
    // MARK: 5. 不同单域策略验证
    // =========================================================================
    // user1 可用角色: RT[1](Editor), RT[3](Observer) —— 均为用户角色
    // user2 可用角色: RT[2](Moderator) —— 用户角色

    @Test("AsiaPacific域(DT.ids[1])：region=asia 时允许，region=na 时拒绝")
    func judgeAsiaPacificDomain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[1] -> GT.ids[1] -> DT.ids[1]: region=="asia"
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 3, s: s) // RT[3] = ObserverRole: view (user1 用户角色)

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allow.result, "region=asia → AsiaPacific 域通过 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(!deny.result, "region=na → AsiaPacific 域失败 → DENY")
    }

    @Test("NorthAmerica域(DT.ids[2])：region=na 时允许，region=asia 时拒绝")
    func judgeNorthAmericaDomain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[2] -> GT.ids[2] -> DT.ids[2]: region=="na"
        let user = try await fetchUser(index: 2, s: s)
        let role = try await fetchRole(index: 2, s: s) // RT[2] = ModeratorRole: moderate (user2 用户角色)

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(allow.result, "region=na → NorthAmerica 域通过 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(!deny.result, "region=asia → NorthAmerica 域失败 → DENY")
    }

    // =========================================================================
    // MARK: 6. 双域 AND（AT.ids[3] -> GT.ids[0]+GT.ids[3] -> domain0+domain3）
    // =========================================================================
    // domain0: global==true，domain3: env==sandbox
    // user3 可用角色: RT[4](用户角色, allow if {true}), RT[5](群组角色 via group3, allow if {true})

    @Test("双域AND：全部满足 → ALLOW，reports 包含 3 个域")
    func judgeMultiDomain_AllPass() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user3: userInGroups[3]=[0,3] → group0(domain0: global==true) + group3(domain3: env==sandbox)
        // 同时直接赋予 domain4(allow if {true})
        // 因此 domain reports 共 3 个: domain0 + domain3 + domain4
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 4, s: s) // RT[4]: allow if {true}（user3 的用户角色）

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true), "env": AnyCodable("sandbox")]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "role+domain0+domain3+domain4 全通过 → ALLOW")
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(domainReports.count == 3, "应有 3 个域报告: domain0(群组)+domain3(群组)+domain4(用户直接)")
        #expect(domainReports.values.allSatisfy { $0 })
    }

    @Test("双域AND：domain3(env==sandbox)不满足 → DENY")
    func judgeMultiDomain_Domain3Fails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 4, s: s) // RT[4]: allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "domain3 要求 env==sandbox，缺失 → DENY")
        #expect(res.reports.filter { $0.key.type == .domain }.values.contains(false))
    }

    @Test("双域AND：domain0(global==true)不满足 → DENY")
    func judgeMultiDomain_Domain0Fails() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 5, s: s) // RT[5]: 群组角色，allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["env": AnyCodable("sandbox")]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "domain0 要求 global==true，缺失 → DENY")
    }

    @Test("双域AND：两个群组域均不满足 → DENY（但 domain4 直接域仍通过）")
    func judgeMultiDomain_BothFail() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user3 域: group0(domain0: global==true) + group3(domain3: env==sandbox) + 直接 domain4(allow all)
        // 传空 resource：domain0失败, domain3失败, domain4通过
        // AND 逻辑下，任一失败则整体 DENY
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 4, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "domain0/domain3 均失败 → 整体 DENY（即使 domain4 通过）")
        // domain4(allow all) 为 true，所以不能断言所有域均为 false
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(domainReports.values.contains(false), "至少 domain0 或 domain3 不满足 → 应包含 false")
    }

    // =========================================================================
    // MARK: 7. 四域极端 AND（AT.ids[5] -> domain0,1,2,3）
    // =========================================================================
    // user5 直接用户角色 = [RT[8],RT[9]]
    // userInGroups[5]=[0,1,2,3] → group0(domain0) + group1(domain1) + group2(domain2) + group3(domain3)
    // user5 直接用户域 = [domain8,domain9] (均 allow if {true})
    // domain reports 共 6 个: domain0~3(群组) + domain8,9(用户直接)
    // domain1(asia) 和 domain2(na) 互斥，region 不能同时满足，验证 AND 严格性

    @Test("四域极端AND：domain1(asia)与domain2(na)互斥 → 始终 DENY")
    func judgeQuadDomain_AlwaysDeny() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user5: 直接用户角色 RT[8]/RT[9]，全部为 allow if {true}
        // user5 在 group0~3 + 直接域 domain8/9，共 6 个 domain
        let user = try await fetchUser(index: 5, s: s)
        let role = try await fetchRole(index: 8, s: s) // RT[8]: allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [
                "global": AnyCodable(true),
                "env": AnyCodable("sandbox"),
                "region": AnyCodable("asia") // domain2 需要 na，并预 asia → domain2 失败
            ]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "domain2 需要 region=na，与 domain1 的 asia 互斥 → 始终 DENY")
        let domainReports = res.reports.filter { $0.key.type == .domain }
        // user5 有 6 个 domain：domain0(群组)+domain1(群组)+domain2(群组)+domain3(群组)+domain8(直接)+domain9(直接)
        #expect(domainReports.count == 6, "6 个 domain: 4 个群组域 + 2 个用户直接域")
        #expect(domainReports.values.contains(false), "domain2(na)与 domain1(asia)互斥 → 应有 false")
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
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allow.result, "ObserverRole + domain0 全满足 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .view, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .edit, privilegeIds: []
        ).get()

        #expect(!res.result, "SuperAdminRole 不允许 edit，domain 通过也 DENY")
    }

    // =========================================================================
    // MARK: 9. 策略语义变更与仲裁
    // =========================================================================

    @Test("Role 策略替换：新语义立即影响仲裁结果（deploy 限制）")
    func rolePolicy_ReplaceAndRejudge() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // 使用 RT.ids[12](ContentReviewer)，属于 user8(用户角色)
        // group10 属于 group2(DeveloperHub, domain2: region=na) 的子群组
        //      所以初始 judge 需要 region=na 来满足 domain2
        let targetId = RT.ids[12]
        let user = try await fetchUser(index: 8, s: s)
        let role = try await fetchRole(index: 12, s: s) // RT[12] = user8 的用户角色

        // 替换前：allow if { true } → 任何操作都通过（配合 region=na 满足域策略）
        let before = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .anything, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .deploy, privilegeIds: []
        ).get()
        #expect(deployRes.result, "替换后：deploy → ALLOW")

        let denyRes = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .anything, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .edit, privilegeIds: []
        ).get()
        #expect(allow.result, "EditorRole + region=asia → ALLOW")

        // ✗ 欧洲地区 + publish（region 不匹配 domain1）
        let denyRegion = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("eu")]),
            operation: .publish, privilegeIds: []
        ).get()
        #expect(!denyRegion.result, "region=eu → AsiaPacific 域失败 → DENY")

        // ✗ 正确地区但无权操作
        let denyOp = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .manage_all, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(allow.result, "ModeratorRole + region=na → ALLOW")

        let denyAsia = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(!denyAsia.result, "region=asia → NorthAmerica 域失败 → DENY")

        let denyEdit = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .edit, privilegeIds: []
        ).get()
        #expect(!denyEdit.result, "ModeratorRole 不允许 edit → DENY")
    }

    @Test("综合：RT[4](默认放行) + GlobalScope+Sandbox 双域，精准访问控制矩阵")
    func comprehensive_ObserverTwoDomains() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[3] → GT.ids[0](domain0: global==true) + GT.ids[3](domain3: env==sandbox)
        // user3 可用角色: RT[4](用户角色, allow if {true}), RT[5](群组角色 via group3)
        let user = try await fetchUser(index: 3, s: s)
        let role = try await fetchRole(index: 4, s: s) // RT[4]: allow if {true}

        struct Case {
            let resource: JsonResource
            let op: JsonOperation
            let expected: Bool
            let desc: String
        }

        let cases: [Case] = [
            .init(resource: JsonResource(name: "test", content: ["global": AnyCodable(true), "env": AnyCodable("sandbox")]),
                  op: .view, expected: true,   desc: "双域全满足 + view → ALLOW"),
            .init(resource: JsonResource(name: "test", content: ["global": AnyCodable(false), "env": AnyCodable("sandbox")]),
                  op: .view, expected: false,  desc: "global=false → domain0 失败 → DENY"),
            .init(resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
                  op: .view, expected: false,  desc: "env 缺失 → domain3 失败 → DENY"),
            .init(resource: JsonResource(name: "test", content: [:]), op: .view, expected: false, desc: "两域均失败 → DENY")
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
        // user4 可用角色: RT[6], RT[7](均为 allow if {true})
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 6, s: s) // RT[6]: allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .anything, privilegeIds: []
        ).get()
        #expect(res.result, "空 privilegeIds 不影响纯角色鉴权")
    }

    @Test("资源权限：privilegeIds 非空时，privilege 策略参与最终 AND")
    func edge_PrivilegePolicyParticipatesInAnd() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 6, s: s) // RT[6]: allow if {true}
        let suffix = UUID().uuidString

        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "PolicyTestReadPrivilege-\(suffix)",
                description: "PolicyTests 临时资源权限",
                policy: "allow if { input.operation == \"read\" }"
            )
        ]).get()
        let privilege = try #require(privileges.first)

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .read, privilegeIds: [privilege.id]
        ).get()
        #expect(allow.result, "role/domain/privilege 均通过 → ALLOW")

        let privilegeKey = PrivilegeSystem.Arbitrator.Result.IdKey(
            type: .privilege, moduleId: m.moduleId, id: privilege.id
        )
        #expect(allow.reports[privilegeKey] == true, "privilege 报告应为 true")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .write, privilegeIds: [privilege.id]
        ).get()
        #expect(!deny.result, "privilege 不允许 write → 整体 DENY")
        #expect(deny.reports[privilegeKey] == false, "privilege 报告应为 false")

        try await m.privilege.delete(policy: privilege).get()
    }

    @Test("资源权限：多个 privilegeIds 必须全部通过，reports 分别记录")
    func edge_MultiplePrivilegePoliciesAreAnded() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 6, s: s) // RT[6]: allow if {true}
        let suffix = UUID().uuidString

        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "PolicyTestReadPrivilege-\(suffix)",
                description: "PolicyTests 临时 read 权限",
                policy: "allow if { input.operation == \"read\" }"
            ),
            .init(
                name: "PolicyTestFilePrivilege-\(suffix)",
                description: "PolicyTests 临时 file 权限",
                policy: "allow if { input.resource.kind == \"file\" }"
            )
        ]).get()
        let readPrivilege = try #require(privileges.first)
        let filePrivilege = try #require(privileges.dropFirst().first)
        let readKey = PrivilegeSystem.Arbitrator.Result.IdKey(
            type: .privilege, moduleId: m.moduleId, id: readPrivilege.id
        )
        let fileKey = PrivilegeSystem.Arbitrator.Result.IdKey(
            type: .privilege, moduleId: m.moduleId, id: filePrivilege.id
        )

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["kind": AnyCodable("file")]),
            operation: .read, privilegeIds: [readPrivilege.id, filePrivilege.id]
        ).get()
        #expect(allow.result, "两个 privilege 均通过 → ALLOW")
        #expect(allow.reports[readKey] == true)
        #expect(allow.reports[fileKey] == true)

        let denyOperation = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["kind": AnyCodable("file")]),
            operation: .write, privilegeIds: [readPrivilege.id, filePrivilege.id]
        ).get()
        #expect(!denyOperation.result, "read privilege 失败 → 整体 DENY")
        #expect(denyOperation.reports[readKey] == false)
        #expect(denyOperation.reports[fileKey] == true)

        let denyResource = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["kind": AnyCodable("directory")]),
            operation: .read, privilegeIds: [readPrivilege.id, filePrivilege.id]
        ).get()
        #expect(!denyResource.result, "file privilege 失败 → 整体 DENY")
        #expect(denyResource.reports[readKey] == true)
        #expect(denyResource.reports[fileKey] == false)

        for privilege in privileges {
            try await m.privilege.delete(policy: privilege).get()
        }
    }

    @Test("边界：有直接用户域的无group用户，domain reports 不为空")
    func edge_NoGroupUser_HasDirectDomainReports() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user4: userInGroups[4]=[] (无 group)，但直接赋予 domain6/domain7
        // domain6/domain7 均为 allow if {true}，空 resource 也通过
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 7, s: s) // RT[7]: user4 的用户角色

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "RT[7](allow all) + domain6/7(allow all) → ALLOW")
        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(!domainReports.isEmpty, "user4 有直接赋予的 domain6/domain7，应有 domain 报告")
        #expect(domainReports.count == 2, "domain6 和 domain7 共 2 个")
        #expect(domainReports.values.allSatisfy { $0 }, "domain6/domain7 均通过")
    }

    @Test("边界：没有任何域约束的用户，仅产生 role report")
    func edge_NoDomainConstraints_RoleOnlyReport() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user9 在 group11 中；group11 没有 domain，user9 也没有直接 domain。
        // RT[7] 通过 roleForGroupUser 指派给 user9 in group11。
        let user = try await fetchUser(index: 9, s: s)
        let role = try await fetchRole(index: 7, s: s)

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]), operation: .anything, privilegeIds: []
        ).get()

        #expect(res.result, "无 domain/privilege 约束时，role 通过即可 ALLOW")
        #expect(res.reports.filter { $0.key.type == .role }.count == 1)
        #expect(res.reports.filter { $0.key.type == .domain }.isEmpty)
        #expect(res.reports.filter { $0.key.type == .privilege }.isEmpty)
    }

    @Test("边界：role 失败时 AND 逻辑使最终结果为 false")
    func edge_RoleFailsAndShortCircuit() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user0 可用角色: RT[0](SuperAdmin), RT[3](Observer)
        // user0 在 group0，绑 domain0(global==true)
        // 测试：SuperAdmin+view → role 失败，即使 domain0 通过也 DENY
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s) // RT[0] = SuperAdminRole: manage_all only

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]), // domain0 通过
            operation: .view, privilegeIds: []
        ).get()

        #expect(!res.result, "role 失败（SuperAdmin 不含 view）→ DENY")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == false)
    }

    @Test("边界：传入不属于用户的 role 时，judge 在策略查询前失败")
    func edge_UnavailableRoleRejectedBeforePolicyEvaluation() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 4, s: s)
        let role = try await fetchRole(index: 0, s: s) // RT[0] 不属于 user4

        do {
            _ = try await s.arbitrator.judge(
                moduleId: m.moduleId, user: user, role: role,
                resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .manage_all, privilegeIds: []
            ).get()
            Issue.record("不可用 role 不应进入仲裁策略查询")
        } catch let err {
            #expect(err.error == .arbitrationDataCollectFailed)
        }
    }

    @Test("边界：默认域策略 allow if {true} 对所有 resource 放行")
    func edge_DefaultDomainAllowsAll() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user6 在 GT.ids[6,7](SalesTeam+MarketingTeam)
        // group6/7 直接绑 domain4(默认 allow if {true})
        // 但父群组 group0 绑 domain0(global==true) 也会继承到 user6
        // 所以 resource={} 时 domain0(global==true) 失败 → DENY
        // 改为测试 global=true 时，domain4 + domain0 全部通过
        // user6 可用角色: RT[10](用户角色), RT[4](组内角色 in group6)
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 10, s: s) // RT[10]: allow if {true}

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]), // 满足继承s的 domain0
            operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "RT[10](allow all) + domain4(allow all) + domain0(global=true) 全通过 → ALLOW")
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
        // user6 可用角色: RT[10](用户角色, allow if {true}), RT[4](组内角色 in group6, allow if {true})
        // group6/7 父群组 group0 绑 domain0(global==true) 会继承到 user6
        // group6/7 直接绑 domain4(allow if {true})
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 10, s: s) // RT[10]: allow if {true}

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allow.result, "子群组用户 + 满足父群组 domain0(global=true) → ALLOW")

        let domainReports = allow.reports.filter { $0.key.type == .domain }
        #expect(!domainReports.isEmpty, "嵌套群组用户应有 domain 报告")
        #expect(domainReports.values.allSatisfy { $0 }, "所有 domain 报告都应为 true")
    }

    @Test("嵌套群组：父群组角色对直接子群组用户可用，并参与仲裁")
    func nestedGroup_ParentGroupRoleAvailableToChildUser() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // Shared.roleForGroup[11] = [group0]，user6 在 group6/group7，二者均为 group0 子群组。
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 11, s: s) // RT[11]: allow if {true}

        let applicableGroups = try await s.role.verify(groupRole: role, appointedTo: user).get()
        #expect(applicableGroups.map { $0.id }.contains(GT.ids[0]), "RT[11] 应作为父群组 group0 的群组角色对 user6 可用")

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()

        #expect(res.result, "父群组角色 + 继承 domain0(global=true) + 子群组 domain4 → ALLOW")
        let roleKey = PrivilegeSystem.Arbitrator.Result.IdKey(type: .role, moduleId: m.moduleId, id: role.id)
        #expect(res.reports[roleKey] == true)
        #expect(res.reports.filter { $0.key.type == .domain }.values.allSatisfy { $0 })
    }



    @Test("嵌套群组：子群组用户父群组 domain0(global==true) 不满足 → global=false DENY")
    func nestedGroup_InheritParentDomain_Deny() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 6, s: s)
        // RT[4]: user6 的组内角色(in group6), allow if {true}
        let role = try await fetchRole(index: 4, s: s)

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .any, privilegeIds: []
        ).get()
        #expect(!deny.result, "global=false → 继承的 domain0 失败 → DENY")

        let domainReports = deny.reports.filter { $0.key.type == .domain }
        #expect(domainReports.values.contains(false), "domain0 报告应为 false")
    }

    @Test("嵌套群组：role 失败时即使父群组域策略全通过也应 DENY")
    func nestedGroup_RoleFailsOverridesDomain() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // user6 可用角色: RT[10](allow if {true}), RT[4](allow if {true})
        // 两种都是 allow all，无法测试 role 失败场景
        // 改为使用 user0(group0)：RT[0](SuperAdmin) + view 操作 → role 失败
        // user0 可用角色: RT[0](SuperAdmin), RT[3](Observer in-group)
        let user = try await fetchUser(index: 0, s: s) // user0 在 group0(domain0: global==true)
        let role = try await fetchRole(index: 0, s: s) // RT[0] SuperAdminRole: manage_all only

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
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
        // user7 可用角色: RT[11](用户角色, allow if {true}), RT[5](组内角色 in group8, allow if {true})
        let user = try await fetchUser(index: 7, s: s)
        let role = try await fetchRole(index: 11, s: s) // RT[11]: allow if {true}

        // 尝试只满足 domain1
        let denyWithAsia = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(!denyWithAsia.result, "region=asia → domain1 通过但 domain2(na) 失败 → DENY")

        // 尝试只满足 domain2
        let denyWithNa = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(!denyWithNa.result, "region=na → domain2 通过但 domain1(asia) 失败 → DENY")

        // 两者均不满足
        let denyEmpty = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: [:]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(!denyEmpty.result, "无 region → 两个父群组域策略均失败 → DENY")
        let domainReports = denyEmpty.reports.filter { $0.key.type == .domain }
        #expect(domainReports.values.allSatisfy { !$0 }, "所有继承域报告应为 false")
    }

    @Test("嵌套群组：单一子群组用户继承父群组 domain2(region=na)")
    func nestedGroup_SingleChildInheritsParentDomain2() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[8] → group10 (Designers，child of group2/DeveloperHub: domain2 region=na)
        // user8 可用角色: RT[12], RT[13](用户角色, allow if {true}), RT[6](组内角色 in group10, allow if {true})
        let user = try await fetchUser(index: 8, s: s)
        let role = try await fetchRole(index: 12, s: s) // RT[12]: allow if {true}

        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allow.result, "region=na → 继承的 domain2 通过 → ALLOW")

        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .view, privilegeIds: []
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
        // user6 可用角色: RT[10](用户角色, allow if {true}), RT[4](组内角色 in group6, allow if {true})
        let user = try await fetchUser(index: 6, s: s)
        let role = try await fetchRole(index: 10, s: s) // RT[10]: allow if {true}

        // global=true → 全通过
        let allPass = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allPass.result, "domain4(直接) + domain0(继承, global=true) + RT[10](allow all) → ALLOW")
        let passDomainReports = allPass.reports.filter { $0.key.type == .domain }
        #expect(passDomainReports.count == 2, "group6/group7 重复获得 domain0/domain4 时，应按 domain id 去重为 2 个报告")
        #expect(passDomainReports.values.allSatisfy { $0 }, "domain0/domain4 均应通过")

        // global=false → domain0(继承) 失败 → DENY
        let inheritFail = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(!inheritFail.result, "domain0(继承) 失败 → 整体 DENY")
    }


    @Test("嵌套群组：用户直接域权限与所在子群组继承的父群组域权限并行验证")
    func nestedGroup_UserDirectDomainPlusInherited() async throws {
        let (s, m) = try await TestingShared.getSystem()
        // AT.ids[0] 在 group0 (AdministratorGroup) 中
        // AT.ids[0] 同时被直接赋予 domain0 (GlobalScope: global==true)
        // user0 可用角色: RT[0](SuperAdmin), RT[3](Observer in-group)—使用 RT[3](Observer)
        let user = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 3, s: s) // RT[3] ObserverRole: view

        let res = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(res.result, "用户直接域 + 群组域均满足 global=true → ALLOW")

        let domainReports = res.reports.filter { $0.key.type == .domain }
        #expect(!domainReports.isEmpty, "应有 domain 报告")
        #expect(domainReports.count == 1, "domain0 同时来自用户直接域和群组域，reports 应按 domain id 去重")
        #expect(domainReports.values.allSatisfy { $0 }, "所有 domain 报告均为 true")

        // global=false → domain0 均失败 → DENY
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .view, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allow.result, "ObserverRole(view) + domain0(global=true) → ALLOW")

        // domain 失败 → DENY（组内角色不能越过域策略）
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .view, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .any_operation, privilegeIds: []
        ).get()
        #expect(allow.result, "SalesManager(allow all) + domain0(global=true) + domain4(allow all) → ALLOW")

        // global=false → 父群组 domain0 失败 → DENY
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(false)]),
            operation: .any_operation, privilegeIds: []
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
            resource: JsonResource(name: "test", content: ["region": AnyCodable("na")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(allowAfterAppoint.result, "appoint 后：ModeratorRole + domain2(region=na) → ALLOW")

        // region=asia → domain2 失败 → DENY
        let denyDomain = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .moderate, privilegeIds: []
        ).get()
        #expect(!denyDomain.result, "region=asia → domain2(na) 失败 → DENY")

        // ─── 第四步：dismiss，撤销 ModeratorRole ────────────────────────────
        try await s.role.dismiss {
            [role] => [rel]
        }.get()

        // dismiss 后 ModeratorRole 不再是 user8 的可用身份；不要再用它调用 judge。
        let stillAvailable = try await s.role.is(role: role, appointedTo: user).get()
        #expect(!stillAvailable, "dismiss 后 ModeratorRole 不应再属于 user8")
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
            resource: JsonResource(name: "test", content: ["region": AnyCodable("asia")]),
            operation: .hr_task, privilegeIds: []
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
        // user0 在 group0 中，RelationTests 将 ObserverRole(view) 指派到 user0 in group0
        // user0 可用角色: RT[0](SuperAdmin, 用户角色), RT[3](Observer, 组内角色)
        // 测试: 当使用 RT[0](SuperAdmin) + view 操作 → role 策略不允许 → DENY
        // 组内 RT[3](Observer) 的存在不干扰 RT[0] 的判定
        let user = try await fetchUser(index: 0, s: s)
        let superAdminRole = try await fetchRole(index: 0, s: s) // RT[0]: manage_all only

        // RT[0] + view → role 策略不通过 → DENY（组内 RT[3] 不干扰）
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: superAdminRole,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(!deny.result, "RT[0] 不允许 view → DENY，组内 RT[3] 不影响此次 judge")

        // RT[0] + manage_all + domain0(global=true) → ALLOW
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: superAdminRole,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .manage_all, privilegeIds: []
        ).get()
        #expect(allow.result, "RT[0] + manage_all + domain0(global=true) → ALLOW")

        // 切换为 RT[3](Observer) + view + global=true → ALLOW
        let observerRole = try await fetchRole(index: 3, s: s)
        let allowObserver = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: observerRole,
            resource: JsonResource(name: "test", content: ["global": AnyCodable(true)]),
            operation: .view, privilegeIds: []
        ).get()
        #expect(allowObserver.result, "RT[3](Observer) + view + global=true → ALLOW")
    }

    // =========================================================================
    // MARK: Resource 与 Privilege 的结合测试
    // =========================================================================

    @Test("Resource + Privilege：Privilege 的策略依赖 resource 的属性，当条件满足时 ALLOW")
    func edge_PrivilegeAndResource_Allowed() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 1, s: s) // EditorRole: edit 或 publish
        
        let jsonResource = JsonResource(name: "public_doc.txt", content: ["isPrivate": AnyCodable(false), "region": AnyCodable("asia")])
        let resourceDTO = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<JsonResource, DTO.Prepare>(data: jsonResource)
        ]).get().first!
        let anyResourceDTO = PM<ResourceList>.AnyResourceDTO(resourceDTO)
        
        // Privilege 策略：要求 input.resource.isPrivate == false 且 operation == edit
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "PublicFileEdit",
                policy: "allow if { input.resource.isPrivate == false; input.operation == \"edit\" }"
            )
        ]).get()
        let privilegeDTO = privileges[0]
        
        try await m.privilege.attach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: jsonResource,
            operation: .edit, privilegeIds: [privilegeDTO.id]
        ).get()
        
        #expect(allow.result, "Resource.isPrivate == false 且 operation == edit，且满足 role/domain，-> ALLOW")
        
        // 验证其他操作被拒绝 (role 允许 publish，但 privilege 拒绝)
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: jsonResource,
            operation: .publish, privilegeIds: [privilegeDTO.id]
        ).get()
        
        #expect(!deny.result, "operation == publish，Privilege 拒绝 -> DENY")
        
        // 清理
        try await m.privilege.detach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        try await m.privilege.delete(policy: privilegeDTO).get()
        try await m.resource.delete(ids: [resourceDTO.id]).get()
    }

    @Test("Resource + Privilege：Privilege 的策略依赖 resource 的属性，当条件不满足时 DENY")
    func edge_PrivilegeAndResource_Denied() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 1, s: s) // EditorRole: edit or publish
        
        // 这是一个私有文件
        let jsonResource = JsonResource(name: "secret_keys.env", content: ["isPrivate": AnyCodable(true), "region": AnyCodable("asia")])
        let resourceDTO = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<JsonResource, DTO.Prepare>(data: jsonResource)
        ]).get().first!
        let anyResourceDTO = PM<ResourceList>.AnyResourceDTO(resourceDTO)
        
        // Privilege 策略：要求 input.resource.isPrivate == false
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "PublicFileEdit_DenyTest",
                policy: "allow if { input.resource.isPrivate == false; input.operation == \"edit\" }"
            )
        ]).get()
        let privilegeDTO = privileges[0]
        
        try await m.privilege.attach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        
        // 尝试 edit (符合 role 策略，但被 privilege 策略拒绝)
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: jsonResource,
            operation: .edit, privilegeIds: [privilegeDTO.id]
        ).get()
        
        #expect(!deny.result, "Resource.isPrivate == true，不满足 Privilege 策略(isPrivate == false) → DENY")
        
        // 清理
        try await m.privilege.detach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        try await m.privilege.delete(policy: privilegeDTO).get()
        try await m.resource.delete(ids: [resourceDTO.id]).get()
    }
    
    @Test("Resource + Privilege：针对 Directory 的属主判断")
    func edge_DirectoryResource_Owner() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let user = try await fetchUser(index: 1, s: s)
        let role = try await fetchRole(index: 1, s: s) // EditorRole
        
        let jsonResource = JsonResource(name: "user_home", content: ["ownerId": AnyCodable(user.id.uuidString), "region": AnyCodable("asia")])
        let resourceDTO = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<JsonResource, DTO.Prepare>(data: jsonResource)
        ]).get().first!
        let anyResourceDTO = PM<ResourceList>.AnyResourceDTO(resourceDTO)
        
        // Privilege 策略：仅要求操作者是属主 (无特定 operation 要求，只要通过 role)
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "DirectoryOwnerOnly",
                policy: "allow if { input.resource.ownerId == input.user.id }"
            )
        ]).get()
        let privilegeDTO = privileges[0]
        
        try await m.privilege.attach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        
        let allow = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: user, role: role,
            resource: jsonResource,
            operation: .edit, privilegeIds: [privilegeDTO.id]
        ).get()
        
        #expect(allow.result, "Directory.ownerId 等于 user.id → ALLOW")
        
        // 测试非属主被拒绝
        // 使用 user0(SuperAdmin), 其带有 global 的要求
        let otherUser = try await fetchUser(index: 0, s: s)
        let otherRole = try await fetchRole(index: 0, s: s)
        
        let jsonResourceOther = JsonResource(name: "user_home", content: ["ownerId": AnyCodable(user.id.uuidString), "global": AnyCodable(true)])
        let deny = try await s.arbitrator.judge(
            moduleId: m.moduleId, user: otherUser, role: otherRole,
            resource: jsonResourceOther,
            operation: .manage_all, privilegeIds: [privilegeDTO.id]
        ).get()
        
        #expect(!deny.result, "Directory.ownerId 不等于 otherUser.id (即 user0.id) → DENY")
        
        // 清理
        try await m.privilege.detach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        try await m.privilege.delete(policy: privilegeDTO).get()
        try await m.resource.delete(ids: [resourceDTO.id]).get()
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
