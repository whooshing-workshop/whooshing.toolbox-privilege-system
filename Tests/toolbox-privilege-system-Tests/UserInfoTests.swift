import Cryptos
import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
@testable import PrivilegeSystem
@testable import PrivilegeModule

@Suite("用户信息 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct UserinfoTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .userInfo {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("创建用户信息")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .userInfo
    }
}
