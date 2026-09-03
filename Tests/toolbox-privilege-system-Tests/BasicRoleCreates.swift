import Testing
import Foundation
@testable import PrivilegeSystem

@Suite("基本角色创建 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct BasicRoleCreatesTesting {
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .basicRoleCreates {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var nobodyRoleId: UUID! = nil
    
    @Test("创建 nobody 账户")
    func nobodyCreate() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let role = try await #require(s.createNobodyIfNotExist())
        
        Self.nobodyRoleId = role.id

        #expect(role.name == "nobody")
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
