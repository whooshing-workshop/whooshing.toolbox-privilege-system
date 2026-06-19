import Foundation
import Testing
import Query
import Collections
import Cryptos
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import DTOBuilder

@Suite("DTO 序列化测试集", .serialized)
struct DTOCodableTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .dtoCodable {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("QToken 序列化和反序列化")
    func testTokenCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let token = try await s.query(QToken.self).first()
        guard let token = token else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(token)
        let decoded = try decoder.decode(QToken.self, from: data)
        
        #expect(decoded.id == token.id)
        #expect(decoded.credential == token.credential)
        #expect(decoded.$user.id == token.$user.id)
    }
    
    @Test("QRole 序列化和反序列化")
    func testRoleCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let role = try await s.query(QRole.self).first()
        guard let role = role else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(role)
        let decoded = try decoder.decode(QRole.self, from: data)
        
        #expect(decoded.id == role.id)
        #expect(decoded.name == role.name)
    }
    
    @Test("QDomain 序列化和反序列化")
    func testDomainCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let domain = try await s.query(QDomain.self).first()
        guard let domain = domain else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(domain)
        let decoded = try decoder.decode(QDomain.self, from: data)
        
        #expect(decoded.id == domain.id)
        #expect(decoded.name == domain.name)
    }
    
    @Test("QGroup 序列化和反序列化")
    func testGroupCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let group = try await s.query(QGroup.self).first()
        guard let group = group else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(group)
        let decoded = try decoder.decode(QGroup.self, from: data)
        
        #expect(decoded.id == group.id)
        #expect(decoded.name == group.name)
    }
    
    @Test("QUserInfo 序列化和反序列化")
    func testUserInfoCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let userInfo = try await s.query(QUserInfo.self).first()
        guard let userInfo = userInfo else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(userInfo)
        let decoded = try decoder.decode(QUserInfo.self, from: data)
        
        #expect(decoded.id == userInfo.id)
        #expect(decoded.nickname == userInfo.nickname)
    }
    
    @Test("QInfoSlice 序列化和反序列化")
    func testInfoSliceCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let slice = try await s.query(QInfoSlice<AlternateEmail>.self).first()
        guard let slice = slice else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(slice)
        let decoded = try decoder.decode(QInfoSlice<AlternateEmail>.self, from: data)
        
        #expect(decoded.id == slice.id)
        #expect(decoded.$userInfo.id == slice.$userInfo.id)
    }
    
    @Test("QPolicy 序列化和反序列化")
    func testPolicyCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let policy = try await s.query(QPolicy<Domain>.self).first()
        guard let policy = policy else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(policy)
        let decoded = try decoder.decode(QPolicy<Domain>.self, from: data)
        
        #expect(decoded.id == policy.id)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
