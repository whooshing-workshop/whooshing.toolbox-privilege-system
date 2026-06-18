import Testing
import Foundation
import Query
import Policy
import Fluent
import OrderedCollections
@preconcurrency import AnyCodable
@testable import DTOBuilder
@testable import PrivilegeSystem
@testable import PrivilegeModule

// =============================================================================
// AdvancePolicyTests.swift
// =============================================================================
// 本测试套件用于验证 OPA 中复杂的鉴权策略，包括使用 pg 访问数据库数据
// 以及使用 OPA 自带的 time 等系统函数进行鉴权。
// =============================================================================

@Suite("高级权限策略 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct AdvancePolicyTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .advancePolicy {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    private func fetchUser(index: Int, s: PrivilegeSystem) async throws -> QUser {
        let model = try await __SDBM.User.query(on: s.db)
            .filter(\.$id == AT.ids[index])
            .with(\.$groups)
            .first()
            
        return try QUser.make(from: try #require(model)).get()
    }

    private func fetchRole(index: Int, s: PrivilegeSystem) async throws -> QRole {
        try #require(
            try await s.query(QRole.self)
                .filter(\.id == RT.ids[index])
                .first()
        )
    }

    // =========================================================================
    // MARK: - 复杂 OPA 策略测试
    // =========================================================================
    // ==================================================
    //  RBAC Privilege Relations Analysis Report
    // ==================================================
    // Target User:   0
    // Target Role:   0           [ AVAILABLE ]
    // --------------------------------------------------
    // Inherit Group: Group-0
    // --------------------------------------------------
    // Active Role:   Role-0      ->  allow if { input.operation == "manage_all" }
    // Bound Domain:  Domain-0    ->  allow if { input.resource.global == true }
    // ==================================================
    @Test("测试基于数据库动态查询的复杂鉴权: pg.full_profile(input.user)")
    func testAdvanceSQLQueryPolicy() async throws {
        let (s, m) = try await TestingShared.getSystem()
        
        let user0 = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)
        
        // 创建复杂策略
        // 我们利用 pg.full_profile() 读取用户信息，并验证 created_at 的 year 或 month
        // 由于测试数据是当下生成的，所以 created_at.year == 2026 或 month == 6
        // 但我们直接使用 created_at.year > 2000 来确保一定放行，作为测试。
        // 而针对另外一个必定失败的条件，比如 created_at.year > 3000。
        
        let passPolicyText = """
        allow if {
            r := pg.full_profile(input.user)
            r.created_at.year > 2000
        }
        """
        
        let privilegeDTO = try await m.privilege.createWithReturning(privileges: [PM.PPrivilege(name: "advance_pass", description: "Advance SQL Pass", policy: passPolicyText)]).first!
        let jsonResource = JsonResource(name: "test", content: ["global": AnyCodable(true)])
        let resourceDTO = try await m.resource.create(resources: [jsonResource]).first!
        let anyResourceDTO = try #require(AnyResource(resourceDTO))
        
        try await m.privilege.attach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }
        
        let passRes = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user0,
            role: role,
            resource: anyResourceDTO,
            operation: .init(op: JsonOperation.manage_all),
            privilegeIds: [privilegeDTO.id]
        )
        
        #expect(passRes.result, "使用 pg.full_profile 查询用户年份 > 2000，应该允许")
        
        let failPolicyText = """
        allow if {
            r := pg.full_profile(input.user)
            r.created_at.year > 3000
        }
        """
        
        let failPrivilegeDTO = try await m.privilege.createWithReturning(privileges: [PM.PPrivilege(name: "advance_fail", description: "Advance SQL Fail", policy: failPolicyText)]).first!
        let failJsonResource = JsonResource(name: "test", content: ["global": AnyCodable(true)])
        let failResourceDTO = try await m.resource.create(resources: [failJsonResource]).first!
        let failAnyResource = try #require(AnyResource(failResourceDTO))

        try await m.privilege.attach {
            OrderedSet([failPrivilegeDTO]) => OrderedSet([failAnyResource])
        }
        
        let failRes = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user0,
            role: role,
            resource: failAnyResource,
            operation: .init(op: JsonOperation.manage_all),
            privilegeIds: [failPrivilegeDTO.id]
        )
        
        #expect(!failRes.result, "使用 pg.full_profile 查询用户年份 > 3000，应该拒绝")
        
        // 清理
        try await m.privilege.detach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }
        try await m.privilege.delete(policy: privilegeDTO)
        try await m.resource.delete(ids: [resourceDTO.id])
        
        try await m.privilege.detach {
            OrderedSet([failPrivilegeDTO]) => OrderedSet([failAnyResource])
        }
        try await m.privilege.delete(policy: failPrivilegeDTO)
        try await m.resource.delete(ids: [failResourceDTO.id])
    }
    
    // ==================================================
    //  RBAC Privilege Relations Analysis Report
    // ==================================================
    // Target User:   0
    // Target Role:   0           [ AVAILABLE ]
    // --------------------------------------------------
    // Inherit Group: Group-0
    // --------------------------------------------------
    // Active Role:   Role-0      ->  allow if { input.operation == "manage_all" }
    // Bound Domain:  Domain-0    ->  allow if { input.resource.global == true }
    // ==================================================
    @Test("测试基于 OPA time 模块的复杂鉴权: time.weekday / time.clock / time.date")
    func testAdvanceTimeModulePolicy() async throws {
        let (s, m) = try await TestingShared.getSystem()
        
        let user0 = try await fetchUser(index: 0, s: s)
        let role = try await fetchRole(index: 0, s: s)
        
        // 测试 time.clock 和 time.date 提取出的年份。
        // created_at.raw 提供的是纳秒格式的时间戳，OPA 的 time 函数正是使用纳秒时间戳。
        let policyText = """
        allow if {
            r := pg.full_profile(input.user)
            
            # 使用 time.date() 将纳秒转换回包含 year, month, day 的数组
            date_arr := time.date(r.created_at.raw)
            date_arr[0] > 2000
            
            # 使用 time.clock() 将纳秒转换回包含 hour, minute, second 的数组
            clock_arr := time.clock(r.created_at.raw)
            clock_arr[0] >= 0
            
            # 使用 time.weekday() 判断是周几 (返回字符串，如 "Monday")
            day := time.weekday(r.created_at.raw)
            day != "InvalidDay"
        }
        """
        
        let privilegeDTO = try await m.privilege.createWithReturning(privileges: [PM.PPrivilege(name: "advance_time", description: "Advance Time Module", policy: policyText)]).first!
        let jsonResource = JsonResource(name: "test", content: ["global": AnyCodable(true)])
        let resourceDTO = try await m.resource.create(resources: [jsonResource]).first!
        let anyResourceDTO = try #require(AnyResource(resourceDTO))
        
        try await m.privilege.attach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }
        
        let judgeRes = try await s.arbitrator.judge(
            moduleId: m.moduleId,
            user: user0,
            role: role,
            resource: anyResourceDTO,
            operation: .init(op: JsonOperation.manage_all),
            privilegeIds: [privilegeDTO.id]
        )
        
        #expect(judgeRes.result, "使用 time 模块对 raw 纳秒解析测试应当通过")
        
        // 清理
        try await m.privilege.detach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }
        try await m.privilege.delete(policy: privilegeDTO)
        try await m.resource.delete(ids: [resourceDTO.id])
    }

    // =========================================================================
    // MARK: 测试结束
    // =========================================================================

    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
