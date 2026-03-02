import Cryptos
import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
import Query
@testable import PrivilegeSystem
@testable import PrivilegeModule

@Suite("账号 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct AccountTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .account {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let users: [(String, String)] = [
        ("user1@example.com", "qwertyu"),
        ("user2@gmail.com", "12839012"),
        ("user3@qq.com", "password"),
        ("user4@whooshings.space", "jzosud-sau8wd"),
        ("user5@example.com", "d-3d-as-df-d"),
        ("user6@example.com", "1238947192")
    ]
    
    static let oldPasswords: [(Int, String)] = [
        (0, "12345678"),
        (1, "asdfuopaisj"),
        (2, "poidoiua"),
        (3, "io28dasfas"),
        (4, "ds8aoikda"),
        (5, "uhalskjdf")
    ]
    
    @Test("User 创建测试", arguments: oldPasswords)
    func create(i: Int, password: String) async throws {
        let email = Self.users[i].0
        let newPassword = Self.users[i].1
        
        let (s, _) = try await TestingShared.getSystem()
        
        let user = try await s.account.register(
            for: .init(
                email: email,
                hashedPasswd: try Crypto.hash(password).get()
            )
        ).get()
        
        #expect(user.email == email)
        
        let token = try await s.account.login(
            by: .init(
                email: email,
                hashedPasswd: try Crypto.hash(password).get()
            )
        ).get()
        
        _ = try await s.account.authenticate(token: try token.toPrepare().get()).get()
        
        let newUser = try await s.account.changePassword(
            for: .init(
                email: email,
                hashedPasswd: try Crypto.hash(password).get()
            ),
            to: try Crypto.hash(newPassword).get()
        ).get()
        
        #expect(newUser.email == user.email)
        
        _ = await #expect(throws: PrivilegeSystem.Errcase.ErrType.self) {
            try await s.account.login(
                by: .init(
                    email: email,
                    hashedPasswd: try Crypto.hash(password).get()
                )
            ).get()
        }
        
        let token2 = try await s.account.login(
            by: .init(
                email: email,
                hashedPasswd: try Crypto.hash(newPassword).get()
            )
        ).get()
        
        #expect(token.credential != token2.credential)
        
        _ = await #expect(throws: PrivilegeSystem.Errcase.ErrType.self) {
            try await s.account.register(
                for: .init(
                    email: email,
                    hashedPasswd: try Crypto.hash(password).get()
                )
            ).get()
        }
    }
    
    @Test("User 查询测试")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let res = try await s.query(DTO.User<DTO.Queried>.self)
            .group(.or) { g in
                g
                    .filter(\.email == "user6@example.com")
                    .filter(\.email == "user5@example.com")
            }
            .all()
            .get()
        
        print("result: ")
        print(res)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .userInfo
    }
}
