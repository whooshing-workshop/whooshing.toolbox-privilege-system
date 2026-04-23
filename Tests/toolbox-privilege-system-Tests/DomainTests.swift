import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Foundation
import Query

typealias DT = DomainTesting

@Suite("域权限 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct DomainTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .domain {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var ids: [UUID] = []
    
    static let domains: [PDomain] = [
        .init(name: "GlobalScope", description: "全系统顶级域，可以影响所有资源"),
        .init(name: "AsiaPacific", description: "亚太地区业务域"),
        .init(name: "NorthAmerica", description: "北美地区业务域"),
        .init(name: "SandboxEnvironment", description: "仅限内部访问的隔离沙盒域")
    ]
    
    static var updates: [(PDomain.Updater, String, @Sendable (QDomain) -> Bool)] {[
        (
            .init(domainId: Self.ids[2]).update(name: "NAMERegion"),
            "尝试更新第三个域的名称标识",
            { $0.name == "NAMERegion" }
        )
    ]}
    
    @Test("创建域")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        _ = try await s.domain.create(domains: Self.domains).get()
    }
    
    @Test("查询域信息和组装")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await s.query(QDomain.self).count().get() == Self.domains.count)
        
        Self.ids = []
        for domainParam in Self.domains {
            let u = try #require(
                try await s.query(QDomain.self)
                    .filter(\.name == domainParam.name)
                    .first()
                    .get()
            )
            Self.ids.append(u.id)
        }
        #expect(Self.ids.count == Self.domains.count)
    }
    
    @Test("作用域权限的挂载流转")
    func relations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allUsers = try await s.query(QUser.self).all().get()
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let allGroups = try await s.query(QGroup.self).all().get()
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        let allDomains = try await s.query(QDomain.self).all().get()
        let qDomains = DomainTesting.ids.compactMap { id in allDomains.first(where: { $0.id == id }) }
        
        try #require(users.count >= 2)
        try #require(groups.count >= 2)
        try #require(qDomains.count >= 3)
        
        // 允许组和用户可以特定域进行绑定
        // qDomains[0] (GlobalScope) -> users[0], users[1]
        try await s.domain.assign {
            [qDomains[0]] => [users[0], users[1]]
        }.get()
        
        // qDomains[1] (AsiaPacific) -> groups[0]
        // qDomains[2] (NorthAmerica) -> groups[1]
        try await s.domain.assign {
            [qDomains[1]] => [groups[0]]
            [qDomains[2]] => [groups[1]]
        }.get()
        
        // 验证特定解绑操作
        // qDomains[0] -x-> users[1]
        try await s.domain.unassign {
            [qDomains[0]] => [users[1]]
        }.get()
        
        // qDomains[1] -x-> groups[0]
        try await s.domain.unassign {
            [qDomains[1]] => [groups[0]]
        }.get()
        
        // 注意由于 Domain 的 unassign 操作是通过 DB 层进行的，为了验证可以再次 assign 或者利用 raw query 测试
    }
    
    @Test("域信息状态更新")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (updater, msg, verifier) in Self.updates {
            let res = try await s.domain.update(with: updater).get()
            #expect(verifier(res), "验证失败: \(msg)")
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .policy // Set to policy to allow PolicyTests to trigger if enabled, or just wait.
    }
}
