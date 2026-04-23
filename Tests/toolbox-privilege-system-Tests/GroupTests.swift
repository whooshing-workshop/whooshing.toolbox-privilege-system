import Testing
import Foundation
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Query

@Suite("群组 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct GroupTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .group {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let groups: [PGroup] = [
        .init(name: "Admins", description: "System Administrators"),
        .init(name: "Users", description: "Normal Users")
    ]
    
    @Test("创建群组")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let created = try await s.group.create(groups: Self.groups).get()
        #expect(created.count == Self.groups.count)
    }
    
    @Test("更新群组")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let groups = try await QGroup.query(on: s).all().get()
        guard let first = groups.first else { return }
        
        let updater = PGroup.Updater(groupId: first.id).update(description: "Updated Description")
        let res = try await s.group.update(with: updater).get()
        #expect(res.description == "Updated Description")
    }
    
    @Test("加入和查询群组")
    func relations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await QUser.query(on: s).all().get()
        let groups = try await QGroup.query(on: s).all().get()
        
        try #require(users.count >= 2)
        try #require(groups.count >= 2)
        
        try await s.group.join {
            [users[0]] => [groups[0]]
            [users[1]] => [groups[1]]
        }.get()
        
        let rels = try await s.group.query(relations: [
            PUserInGroupRelation(user: users[0], group: groups[0])
        ]).get()
        
        #expect(rels.count == 1)
        
        try await s.group.kick {
            [users[1]] => [groups[1]]
        }.get()
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .role
    }
}
