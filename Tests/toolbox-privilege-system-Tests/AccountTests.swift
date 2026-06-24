import Testing
import Foundation
import VaporTesting
@testable import PrivilegeSystem

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
    
    struct AuthTestResult: Content {
        let userEmail: String
        let credential: String
    }
    
    struct VaporlizeMiddleware: AsyncMiddleware {
        func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
            do {
                return try await next.respond(to: request)
            } catch {
                throw error.vaporlized
            }
        }
    }
    
    func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        
        app.databases.use(.postgres(
            configuration: .init(
                hostname: TestingShared.dbHost,
                port: TestingShared.dbPort,
                username: "woo",
                password: "testing",
                database: "privilege_system",
                tls: .disable
            ),
            decodingContext: .default
        ), as: .psql)
        
        app.middleware.use(VaporlizeMiddleware())
        
        let protected = app.routes.grouped(
            TokenAuthenticator(),
            QToken.guardMiddleware()
        )
        protected.post("test-auth") { req -> AuthTestResult in
            let qToken = try req.auth.require(QToken.self)
            return AuthTestResult(userEmail: qToken.user.email, credential: qToken.credential)
        }
        
        do {
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        
        try await app.asyncShutdown()
    }
    
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
        
        let authData = try await s.account.authenticate(token: .make(from: token).get())
        #expect(authData.token.id == token.id)
        #expect(authData.token.credential == token.credential)
        #expect(authData.token.token == token.token)
        #expect(authData.token.$user.loaded == true)
        #expect(authData.token.user.id == user.id)
        #expect(authData.token.user.$info.loaded == true)
        
        let userToken = try AuthorizationToken.make(from: token).get()
        let dbToken = try await token.model(from: s.pgDB).get()
        #expect(try dbToken.verify(password: userToken.tokenHashed) == true)
        
        let wrongToken = AuthorizationToken.init(
            credential: userToken.credential,
            tokenHashed: Crypto.hash(Crypto.Symm.makeKey().data).base64EncodedString()
        )
        
        try await withApp { app in
            try await app.testing().test(.POST, "test-auth", beforeRequest: { req in
                try req.content.encode(userToken)
            }, afterResponse: { res in
                #expect(res.status == .ok)
                let result = try res.content.decode(AuthTestResult.self)
                #expect(result.userEmail == user.email)
                #expect(result.credential == token.credential)
            })
            
            try await app.testing().test(.POST, "test-auth", beforeRequest: { req in
                try req.content.encode(wrongToken)
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })
        }
        
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
