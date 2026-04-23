import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Foundation
import Query

typealias GT = GroupTesting

@Suite("群组 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct GroupTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .group {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var ids: [UUID] = []
    
    static let groups: [PGroup] = [
        .init(name: "AdministratorGroup", description: "全系统管理员的集合群组，拥有最高系统访问权限"),
        .init(name: "OperatorGroup", description: "运营管理群组"),
        .init(name: "DeveloperHub", description: "后端服务器与前端客户端的研发群体"),
        .init(name: "BannedUsers", description: "被封禁和限制访问的用户集合"),
        .init(name: "StandardUsers", description: "普通注册用户群体")
    ]
    
    static var updates: [(PGroup.Updater, String, @Sendable (QGroup) -> Bool)] {[
        (
            .init(groupId: Self.ids[1]).update(description: "核心运营群组"),
            "修改群组1的描述",
            { $0.description == "核心运营群组" }
        ),
        (
            .init(groupId: Self.ids[2]).update(name: "NinjaDevelopers").update(description: "神出鬼没的开发者"),
            "修改群组2的名字与描述",
            { $0.name == "NinjaDevelopers" && $0.description == "神出鬼没的开发者" }
        )
    ]}
    
    @Test("创建群组")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        _ = try await s.group.create(groups: Self.groups).get()
    }
    
    @Test("查询并组装群组数据")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await s.query(QGroup.self).count().get() == Self.groups.count)
        
        let res = try await s.query(QGroup.self)
            .group(.or) { g in
                g.filter(\.name == "OperatorGroup")
                 .filter(\.name == "StandardUsers")
            }
            .all()
            .get()
        
        #expect(res.count == 2)
        
        Self.ids = []
        for groupParam in Self.groups {
            let u = try #require(
                try await s.query(QGroup.self)
                    .filter(\.name == groupParam.name)
                    .first()
                    .get()
            )
            Self.ids.append(u.id)
        }
        
        #expect(Self.ids.count == Self.groups.count)
    }
    
    @Test("多对多群组嵌套与操作")
    func joinAndKick() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allUsers = try await s.query(QUser.self).all().get()
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let allGroups = try await s.query(QGroup.self).all().get()
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        try #require(users.count >= 4)
        try #require(groups.count >= 5)
        
        // 分配用户进不同群组：可以重叠交叉测试
        // users[0] -> groups[0] (Administrator)
        // users[0] -> groups[1] (Operator)
        // users[1] -> groups[2] (DeveloperHub)
        // users[2] -> groups[4] (Standard)
        // users[3] -> groups[4] (Standard)
        try await s.group.join {
            [users[0]] => [groups[0], groups[1]]
            [users[1]] => [groups[2]]
            [users[2], users[3]] => [groups[4]]
        }.get()
        
        let relations = try await s.group.query(relations: [
            users[0] =| groups[0],
            users[0] =| groups[1],
            users[1] =| groups[2]
        ]).get()
        
        #expect(relations.count == 3)
        // 被授权的关系应该符合关联的 ID (因底层查询返回顺序可能变化，使用包含判断)
        #expect(relations.contains(where: { $0.user.id == users[0].id && $0.group.id == groups[0].id }))
        #expect(relations.contains(where: { $0.user.id == users[0].id && $0.group.id == groups[1].id }))
        #expect(relations.contains(where: { $0.user.id == users[1].id && $0.group.id == groups[2].id }))
        
        // 测试将其中一个用户踢出群组: users[0] -x-> groups[1]
        try await s.group.kick {
            [users[0]] => [groups[1]]
        }.get()
        
        // 用户0 从群组1中踢出后不应存在对应 relation
        await #expect(throws: PrivilegeSystem.Errcase.ErrType.self, "踢出群组执行异常，数据仍然存在！") {
            try await s.group.query(relations: [
                users[0] =| groups[1]
            ]).get()
        }
    }
    
    @Test("群组更新测试")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (updater, msg, verifier) in Self.updates {
            let res = try await s.group.update(with: updater).get()
            #expect(verifier(res), "验证失败: \(msg)")
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .role
    }
}
