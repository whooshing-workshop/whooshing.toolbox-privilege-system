import Testing
import Foundation
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Query

@Suite("角色 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct RoleTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .role {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let roles: [PRole] = [
        .init(name: "Manager", description: "Manager Role"),
        .init(name: "Editor", description: "Editor Role")
    ]
    
    @Test("创建角色")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let created = try await s.role.create(roles: Self.roles).get()
        #expect(created.count == Self.roles.count)
    }
    
    @Test("任命和撤职角色")
    func relations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await QUser.query(on: s).all().get()
        let roles = try await QRole.query(on: s).all().get()
        let groups = try await QGroup.query(on: s).all().get()
        
        try #require(users.count >= 2)
        try #require(roles.count >= 2)
        try #require(groups.count >= 1)
        
        try await s.role.appoint {
            [roles[0]] => [users[0]]
        }.get()
        
        try await s.role.appoint {
            [roles[1]] => [groups[0]]
        }.get()
        
        try await s.role.dismiss {
            [roles[0]] => [users[0]]
        }.get()
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .domain
    }
}
