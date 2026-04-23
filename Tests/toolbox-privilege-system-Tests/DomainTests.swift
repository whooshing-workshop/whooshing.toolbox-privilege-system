import Testing
import Foundation
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Query

@Suite("域权限 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct DomainTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .domain {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let domains: [PDomain] = [
        .init(name: "Global", description: "Global Domain"),
        .init(name: "Local", description: "Local Domain")
    ]
    
    @Test("创建域")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let created = try await s.domain.create(domains: Self.domains).get()
        #expect(created.count == Self.domains.count)
    }
    
    @Test("分配和撤销域权限")
    func relations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await QUser.query(on: s).all().get()
        let domains = try await QDomain.query(on: s).all().get()
        
        try #require(users.count >= 2)
        try #require(domains.count >= 2)
        
        try await s.domain.assign {
            [domains[0]] => [users[0]]
        }.get()
        
        try await s.domain.unassign {
            [domains[0]] => [users[0]]
        }.get()
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .policy
    }
}
