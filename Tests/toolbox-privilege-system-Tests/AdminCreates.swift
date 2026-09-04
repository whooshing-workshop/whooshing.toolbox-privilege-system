import Testing
import Foundation
@testable import PrivilegeSystem

@Suite("基本角色创建 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct AdminCreatesTesting {
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .adminCreates {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("创建 Admin 账户", arguments: [
        ("admin_1@testing.com", false),
        ("admin_2@testing.com", false),
        ("admin_3@testing.com", false),
        ("admin_4@testing.com", false),
        ("admin_4@testing.com", true)
    ])
    func adminCreate(email: String, existed: Bool) async throws {
        let (s, _) = try await TestingShared.getSystem()
        let hashedPassword = try Crypto.hash("1234567890").get()
        let u = try await s.createAdminIfNotExist(to: TestingShared.systemModuleId, for: .init(email: email, hashedPassword: hashedPassword.base64EncodedString()))
       
        if let user = u {
            #expect(existed == false)
            
            let token = try await s.account.login(by: .init(email: email, hashedPassword: hashedPassword))
            let authData = try await s.account.authenticate(token: .make(from: token).get(), roleId: BasicRoleCreatesTesting.nobodyRoleId)
            
            #expect(authData.token.id == token.id)
            #expect(authData.token.credential == token.credential)
            #expect(authData.token.token == token.token)
            #expect(authData.token.$user.loaded == true)
            #expect(authData.token.user.id == user.id)
            #expect(authData.token.user.$info.loaded == true)
            #expect(authData.role.id == BasicRoleCreatesTesting.nobodyRoleId)
            #expect(authData.role.name == "nobody")
            
            #expect(user.email == email)
        } else {
            #expect(existed == true)
        }
    }
    
    @Test("私自创建 Admin role 应当失败")
    func adminCreateShouldFail() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let role = PRole(name: "admin")
        await #expect(throws: PrivilegeSystem.Errcase.ErrType.self) {
            try await s.role.create(roles: [role])
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
