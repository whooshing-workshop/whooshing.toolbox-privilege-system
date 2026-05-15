import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Foundation
import Query
import Policy
import Fluent

typealias RT = RoleTesting

@Suite("角色 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct RoleTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .role {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var ids: [UUID] = []
    
    static let roles: [PRole] = [
        .init(name: "SuperAdminRole", description: "拥有全局控制面板访问权限"),
        .init(name: "EditorRole", description: "可以编辑及发布内容"),
        .init(name: "ModeratorRole", description: "可以审阅社区发言并封禁违规用户"),
        .init(name: "ObserverRole", description: "只读权限角色"),
        .init(name: "SalesManager", description: "销售部经理角色"),
        .init(name: "HRLead", description: "人力资源总监角色"),
        .init(name: "QAAnalyst", description: "测试分析师角色"),
        .init(name: "GuestRole", description: "访客受限角色"),
        .init(name: "BillingAdmin", description: "财务账单管理角色"),
        .init(name: "SecurityOfficer", description: "安全合规管理角色"),
        .init(name: "DataScientist", description: "数据科学家角色"),
        .init(name: "ProductManager", description: "产品经理角色"),
        .init(name: "ContentReviewer", description: "内容审核专员角色"),
        .init(name: "DevOpsEngineer", description: "运维工程师角色")
    ]
    
    static let defaultPolicy: String = """
    allow if {
        true
    }
    """
    
    // 可以在这里为您定义的每一个角色自定义专属 Policy，如果为 nil 则会使用上面的 defaultPolicy
    static let customPolicies: [String?] = [
        """
        allow if {
            input.operation == "manage_all"
        }
        """, // 0: SuperAdminRole
        nil, // 1: EditorRole
        nil, // 2: ModeratorRole
        nil, // 3: ObserverRole
        nil, // 4: SalesManager
        nil, // 5: HRLead
        nil, // 6: QAAnalyst
        nil, // 7: GuestRole
        nil, // 8: BillingAdmin
        nil, // 9: SecurityOfficer
        nil, // 10: DataScientist
        nil, // 11: ProductManager
        nil, // 12: ContentReviewer
        nil  // 13: DevOpsEngineer
    ]
    
    static var updates: [(PRole.Updater, String, @Sendable (QRole) -> Bool)] {[
        (
            .init(roleId: Self.ids[1]).update(name: "AdvancedEditorRole"),
            "将编辑角色更名",
            { $0.name == "AdvancedEditorRole" }
        ),
        (
            .init(roleId: Self.ids[3]).update(description: "静默观察器"),
            "将观察角色描述更改",
            { $0.description == "静默观察器" }
        )
    ]}
    
    @Test("创建角色")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        _ = try await s.role.create(roles: Self.roles).get()
    }
    
    @Test("查询并验证角色")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await s.query(QRole.self).count().get() == Self.roles.count)
        
        Self.ids = []
        for roleParam in Self.roles {
            let u = try #require(
                try await s.query(QRole.self)
                    .filter(\.name == roleParam.name)
                    .first()
                    .get()
            )
            Self.ids.append(u.id)
        }
        #expect(Self.ids.count == Self.roles.count)
    }
    
    @Test("为每个角色创建默认策略")
    func createPolicies() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let allRoles = try await s.query(QRole.self).all().get()
        let roles = Self.ids.compactMap { id in allRoles.first(where: { $0.id == id }) }
        
        for (i, role) in roles.enumerated() {
            let policyString = (i < Self.customPolicies.count ? Self.customPolicies[i] : nil) ?? Self.defaultPolicy
            
            let policy = PPolicy<Role>(
                moduleId: m.moduleId,
                policy: policyString
            )
            _ = try await s.policy.create(to: Role.self) {
                [policy] => role.id
            }.get()
        }
    }
    
    @Test("验证角色策略是否成功添加")
    func verifyPolicies() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allRoles = try await s.query(QRole.self).all().get()
        let roles = Self.ids.compactMap { id in allRoles.first(where: { $0.id == id }) }
        
        for role in roles {
            let policies = try await PolicyExp<Role>.query(on: s.db)
                .filter(\.$parent.$id == role.id)
                .all().get()
            
            #expect(!policies.isEmpty, "角色 \(role.name) 应当至少包含一条关联策略")
        }
    }
    
    @Test("角色更新测试")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (updater, msg, verifier) in Self.updates {
            let res = try await s.role.update(with: updater).get()
            #expect(verifier(res), "验证失败: \(msg)")
        }
    }
    
    @Test("角色多重关联与撤除测试")
    func appointAndDismissAll() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all().get()
        let groups = try await s.query(QGroup.self).all().get()
        let roles = try await s.query(QRole.self).all().get()
        
        let user = users[1]
        let group = groups[1]
        let role = roles[1]
        
        // 1. Role <-> User
        try await s.role.appoint { [role] => [user] }.get()
        let c1 = try await UserRolePivot.query(on: s.db)
            .count().get()
        #expect(c1 == 1)
        try await s.role.dismiss { [role] => [user] }.get()
        let c2 = try await UserRolePivot.query(on: s.db)
            .count().get()
        #expect(c2 == 0)

        // 2. Role <-> Group
        try await s.role.appoint { [role] => [group] }.get()
        let c3 = try await RoleGroupPivot.query(on: s.db)
            .count().get()
        #expect(c3 == 1)
        try await s.role.dismiss { [role] => [group] }.get()
        let c4 = try await RoleGroupPivot.query(on: s.db)
            .count().get()
        #expect(c4 == 0)

        // 3. Role <-> UserInGroup
        // 先建立 User <-> Group 关系才能指派组内用户的角色
        try await s.group.join { [user] => [group] }.get()
        let uig = try await s.group.query(relations: [user =| group]).get()
        try await s.role.appoint { [role] => uig }.get()
        let c5 = try await RoleUserInGroupPivot.query(on: s.db)
            .count().get()
        #expect(c5 == 1)
        try await s.role.dismiss { [role] => uig }.get()
        let c6 = try await RoleUserInGroupPivot.query(on: s.db)
            .count().get()
        #expect(c6 == 0)
        
        // 扫尾清理 User <-> Group
        try await s.group.kick { [user] => [group] }.get()
    }
    
    @Test("角色删除测试")
    func delete() async throws {
        let (s, m) = try await TestingShared.getSystem()
        
        // 临时创建一个角色用于删除测试
        let tempRole = try await s.role.create(roles: [
            .init(name: "TempDeleteRole", description: "临时删除测试角色")
        ]).get()
        
        let countBefore = try await s.query(QRole.self).count().get()
        #expect(countBefore == Self.roles.count + 1)
        
        let tempId = try #require(tempRole.first?.id)
        try await s.role.delete(roleIds: [tempId]).get()
        
        let countAfter = try await s.query(QRole.self).count().get()
        #expect(countAfter == Self.roles.count, "删除后角色数量应恢复")
        
        let found = try await s.query(QRole.self)
            .filter(\.name == "TempDeleteRole")
            .first().get()
        #expect(found == nil, "被删除的角色不应被查询到")
        
        // 忳照 allSatisfy = false 不抛异常
        let nonExistentId = UUID()
        try await s.role.delete(roleIds: [nonExistentId], allSatisfy: false).get()
    }
    
    @Test("通过 Prepare 关系指派组内用户角色")
    func appointDismissWithPrepare() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all().get()
        let groups = try await s.query(QGroup.self).all().get()
        let roles = try await s.query(QRole.self).all().get()
        
        let user = users[3]
        let group = groups[3]
        let role = roles[3]
        
        // 建立群组内关系
        try await s.group.join { [user] => [group] }.get()
        
        // 使用 Prepare DTO 指派角色
        let prepareRelation = DTO.UserInGroupRelation<DTO.Prepare>(user: user, group: group)
        try await s.role.appoint { [role] => [prepareRelation] }.get()
        
        let c1 = try await RoleUserInGroupPivot.query(on: s.db).count().get()
        #expect(c1 == 1)
        
        // 使用 Prepare DTO 撤除角色
        try await s.role.dismiss { [role] => [prepareRelation] }.get()
        let c2 = try await RoleUserInGroupPivot.query(on: s.db).count().get()
        #expect(c2 == 0)
        
        // 清理
        try await s.group.kick { [user] => [group] }.get()
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .domain
    }
}
