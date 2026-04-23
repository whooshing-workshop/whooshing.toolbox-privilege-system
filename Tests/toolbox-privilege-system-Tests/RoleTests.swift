import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Foundation
import Query

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
        .init(name: "ObserverRole", description: "只读权限角色")
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
    
    @Test("查询并组装角色集")
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
    
    @Test("角色的任命与撤职")
    func relations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allUsers = try await s.query(QUser.self).all().get()
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let allGroups = try await s.query(QGroup.self).all().get()
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        let allRoles = try await s.query(QRole.self).all().get()
        let qRoles = RoleTesting.ids.compactMap { id in allRoles.first(where: { $0.id == id }) }
        
        try #require(users.count >= 2)
        try #require(groups.count >= 2)
        try #require(qRoles.count >= 4)
        
        // 测试将角色赋权给 Group 和 User
        // qRoles[0] (SuperAdminRole) -> users[0]
        // qRoles[2] (ModeratorRole) -> users[1], users[2]
        try await s.role.appoint {
            [qRoles[0]] => [users[0]]       // 用户0被赋予 SuperAdmin
            [qRoles[2]] => [users[1], users[2]]
        }.get()
        
        // qRoles[1] (EditorRole) -> groups[1]
        try await s.role.appoint {
            [qRoles[1]] => [groups[1]]      // 组1被赋予 Editor
        }.get()
        
        // 测试群组内独立赋权：只在属于某个群组的上下文中让某人充当该角色
        let relReq = try await s.group.query(
            relations: [
                users[1] =| groups[2]
            ]
        ).get()
        
        // 注意 SQL 查询可能顺序变化，故使用 first(where:) 进行准确匹配
        // qRoles[3] (ObserverRole) -> (users[1] in groups[2])
        if let rel = relReq.first(where: { $0.user.id == users[1].id && $0.group.id == groups[2].id }) {
            try await s.role.appoint {
                [qRoles[3]] => [rel]        // User1 在 Group2 (DeveloperHub) 时拥有 Observer 权限
            }.get()
        }
        
        // 测试撤除
        // qRoles[0] (SuperAdminRole) -x-> users[0]
        // qRoles[2] (ModeratorRole) -x-> users[1]
        try await s.role.dismiss {
            [qRoles[0]] => [users[0]]
            [qRoles[2]] => [users[1]]
        }.get()
    }
    
    @Test("角色更新测试")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (updater, msg, verifier) in Self.updates {
            let res = try await s.role.update(with: updater).get()
            #expect(verifier(res), "验证失败: \(msg)")
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .domain
    }
}
