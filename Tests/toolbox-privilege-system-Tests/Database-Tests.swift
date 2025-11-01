import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
@testable import PrivilegeSystem

@Suite("PrivilegeSystem 测试集", .serialized, .enabled(if: TestingShared.dbListening))
struct PrivilegeSystemTests {
    @Test("Tests")
    func tests() async throws {
        let ps = try await TestingShared.getSystem()
    }
}
