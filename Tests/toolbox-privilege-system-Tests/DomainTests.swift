import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Foundation
import Query
import Policy
import Fluent

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
        .init(name: "SandboxEnvironment", description: "仅限内部访问的隔离沙盒域"),
        .init(name: "Europe", description: "欧洲业务域"),
        .init(name: "SouthAmerica", description: "南美洲业务域"),
        .init(name: "Africa", description: "非洲业务域"),
        .init(name: "InternalOnly", description: "仅限内网访问"),
        .init(name: "PublicFacing", description: "面向公众的服务域"),
        .init(name: "Development", description: "开发环境域"),
        .init(name: "Staging", description: "预发布环境域"),
        .init(name: "Production", description: "生产环境域"),
        .init(name: "LegacySystem", description: "遗留老系统域"),
        .init(name: "PartnerNetwork", description: "合作伙伴网络域")
    ]
    
    static let defaultPolicy: String = """
    allow if {
        true
    }
    """
    
    // 可以在这里为您定义的每一个域自定义专属 Policy，如果为 nil 则会使用上面的 defaultPolicy
    static let customPolicies: [String?] = [
        """
        allow if {
            input.resource.global == true
        }
        """, // 0: GlobalScope
        nil, // 1: AsiaPacific
        nil, // 2: NorthAmerica
        nil, // 3: SandboxEnvironment
        nil, // 4: Europe
        nil, // 5: SouthAmerica
        nil, // 6: Africa
        nil, // 7: InternalOnly
        nil, // 8: PublicFacing
        nil, // 9: Development
        nil, // 10: Staging
        nil, // 11: Production
        nil, // 12: LegacySystem
        nil  // 13: PartnerNetwork
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
    
    @Test("为每个域创建默认策略")
    func createPolicies() async throws {
        let (s, m) = try await TestingShared.getSystem()
        let allDomains = try await s.query(QDomain.self).all().get()
        let domains = Self.ids.compactMap { id in allDomains.first(where: { $0.id == id }) }
        
        for (i, domain) in domains.enumerated() {
            let policyString = (i < Self.customPolicies.count ? Self.customPolicies[i] : nil) ?? Self.defaultPolicy
            
            let policy = PPolicy<Domain>(
                moduleId: m.moduleId,
                policy: policyString
            )
            _ = try await s.policy.create(to: Domain.self) {
                [policy] => domain.id
            }.get()
        }
    }
    
    @Test("验证域策略是否成功添加")
    func verifyPolicies() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allDomains = try await s.query(QDomain.self).all().get()
        let domains = Self.ids.compactMap { id in allDomains.first(where: { $0.id == id }) }
        
        for domain in domains {
            let policies = try await PolicyExp<Domain>.query(on: s.db)
                .filter(\.$parent.$id == domain.id)
                .all().get()
            
            #expect(!policies.isEmpty, "域 \(domain.name) 应当至少包含一条关联策略")
        }
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
        TestingShared.testStage = .userInfo // Set to policy to allow PolicyTests to trigger if enabled, or just wait.
    }
}
