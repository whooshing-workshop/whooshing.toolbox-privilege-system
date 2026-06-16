import Cryptos
import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
import Query
import OrderedCollections
@testable import PrivilegeSystem
@testable import PrivilegeModule

typealias AT = AccountTesting

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
        ("user6@example.com", "1238947192"),
        ("user7@example.com", "pass7word"),
        ("user8@example.com", "pass8word"),
        ("user9@example.com", "pass9word"),
        ("user10@example.com", "pass10word"),
        ("user11@example.com", "pass11word"),
        ("user12@example.com", "pass12word"),
        ("user13@example.com", "pass13word"),
        ("user14@example.com", "pass14word"),
        ("user15@example.com", "pass15word"),
        ("user16@example.com", "pass16word")
    ]
    
    static let oldPasswords: [(Int, String)] = [
        (0, "12345678"),
        (1, "asdfuopaisj"),
        (2, "poidoiua"),
        (3, "io28dasfas"),
        (4, "ds8aoikda"),
        (5, "uhalskjdf"),
        (6, "oldpass7"),
        (7, "oldpass8"),
        (8, "oldpass9"),
        (9, "oldpass10"),
        (10, "oldpass11"),
        (11, "oldpass12"),
        (12, "oldpass13"),
        (13, "oldpass14"),
        (14, "oldpass15"),
        (15, "oldpass16")
    ]
    
    nonisolated(unsafe) static var ids: OrderedSet<UUID> = []
    
    @Test("User 创建测试", arguments: oldPasswords)
    func create(i: Int, password: String) async throws {
        let email = Self.users[i].0
        let newPassword = Self.users[i].1
        
        let (s, _) = try await TestingShared.getSystem()
        
        let user = try await s.account.register(
            for: .init(
                email: email,
                hashedPassword: try Crypto.hash(password).get()
            )
        )
        
        #expect(user.email == email)
        
        let token = try await s.account.login(
            by: .init(
                email: email,
                hashedPassword: try Crypto.hash(password).get()
            )
        )
        
        _ = try await s.account.authenticate(token: try token.toPrepare().get())
        
        let newUser = try await s.account.changePassword(
            for: .init(
                email: email,
                hashedPassword: try Crypto.hash(password).get()
            ),
            to: try Crypto.hash(newPassword).get()
        )
        
        #expect(newUser.email == user.email)
        
        _ = await #expect(throws: PrivilegeSystem.Errcase.ErrType.self) {
            try await s.account.login(
                by: .init(
                    email: email,
                    hashedPassword: try Crypto.hash(password).get()
                )
            )
        }
        
        let token2 = try await s.account.login(
            by: .init(
                email: email,
                hashedPassword: try Crypto.hash(newPassword).get()
            )
        )
        
        #expect(token.credential != token2.credential)
        
        _ = await #expect(throws: PrivilegeSystem.Errcase.ErrType.self) {
            try await s.account.register(
                for: .init(
                    email: email,
                    hashedPassword: try Crypto.hash(password).get()
                )
            )
        }
    }
    
    @Test("User 查询测试")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await s.query(QUser.self).count() == Self.users.count);
        
        let res = try await s.query(QUser.self)
            .group(.or) { g in
                g
                    .filter(\.email == "user6@example.com")
                    .filter(\.email == "user5@example.com")
            }
            .all()
            
        
        #expect(res.count == 2)
        #expect(res.contains { $0.email == "user6@example.com" })
        #expect(res.contains { $0.email == "user5@example.com" })
        
        Self.ids = []
        
        for user in Self.users {
            let u = try #require(
                try await s.query(QUser.self)
                    .filter(\.email == user.0)
                    .first()
                    
            )
            
            Self.ids.append(u.id)
        }
        
        #expect(Self.ids.count == Self.users.count)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
