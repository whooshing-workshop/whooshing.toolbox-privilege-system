//import Testing
//import Foundation
//@testable import PrivilegeSystem
//@testable import PrivilegeModule
//import Query
//
//@Suite("权限策略 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
//struct PolicyTesting {
//    
//    @Test("开始测试")
//    func start() async throws {
//        while await TestingShared.testStage != .policy {
//            try await Task.sleep(nanoseconds: 250_000_000)
//        }
//    }
//    
//    @Test("创建策略")
//    func create() async throws {
//        let (s, m) = try await TestingShared.getSystem()
//        let roles = try await QRole.query(on: s).all().get()
//        try #require(roles.count >= 1)
//        
//        let policyStr = """
//        package privilege
//        default allow = true
//        """
//        
//        let policy = PPolicy<Role>(moduleId: m.moduleId, policy: policyStr)
//        
//        try await s.policy.create(to: Role.self) {
//            [policy] => roles[0].id
//        }.get()
//    }
//    
//    @Test("检查策略语法")
//    func check() async throws {
//        let (s, _) = try await TestingShared.getSystem()
//        
//        let policyStr = """
//        package privilege
//        default allow = true
//        """
//        
//        let res = try await s.policy.check(policy: policyStr).get()
//        switch res {
//        case .success:
//            #expect(true)
//        case .failure:
//            Issue.record("策略检查失败")
//        }
//    }
//    
//    @MainActor
//    @Test("测试结束")
//    func end() async throws {
//        TestingShared.testStage = .end
//    }
//}
