import Foundation
import Testing
import Query
import Collections
import Cryptos
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import DTOBuilder

@Suite("DTO Updater 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct UpdaterTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .pivotDTO {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("PDomain.Updater 测试")
    func testDomainUpdater() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let domains = try await s.query(QDomain.self).limit(1).all()
        guard let domain = domains.first else { return }
        
        let oldName = domain.name ?? ""
        let oldDesc = domain.summary
        
        let updater1 = PDomain.Updater(domainId: domain.id)
            .update(name: "UpdatedName")
            .update(summary: "UpdatedDesc")
        _ = try await s.domain.update(with: updater1)
        
        let updater2 = PDomain.Updater(domainId: domain.id)
            .update(name: { _ in oldName })
            .update(summary: { _ in oldDesc })
        _ = try await s.domain.update(with: updater2)
    }
    
    @Test("PRole.Updater 测试")
    func testRoleUpdater() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let roles = try await s.query(QRole.self).limit(1).all()
        guard let role = roles.first else { return }
        
        let oldName = role.name
        let oldDesc = role.summary
        
        let updater1 = PRole.Updater(roleId: role.id)
            .update(name: "UpdatedRoleName")
            .update(summary: "UpdatedRoleDesc")
        _ = try await s.role.update(with: updater1)
        
        let updater2 = PRole.Updater(roleId: role.id)
            .update(name: { _ in oldName })
            .update(summary: { _ in oldDesc })
        _ = try await s.role.update(with: updater2)
    }
    
    @Test("PGroup.Updater 测试")
    func testGroupUpdater() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let groups = try await s.query(QGroup.self).limit(2).all()
        guard let group = groups.first else { return }
        
        let oldName = group.name
        let oldDesc = group.summary
        let updater1 = PGroup.Updater(groupId: group.id)
            .update(name: "UpdatedGroupName")
            .update(summary: "UpdatedGroupDesc")
        _ = try await s.group.update(with: updater1)
        
        let updater2 = PGroup.Updater(groupId: group.id)
            .update(name: { _ in oldName })
            .update(summary: { _ in oldDesc })
        _ = try await s.group.update(with: updater2)
    }
    
    @Test("PUserInfo.Updater 测试")
    func testUserInfoUpdater() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let userInfos = try await s.query(QUserInfo.self).limit(1).all()
        guard let userInfo = userInfos.first else { return }
        
        let oldNickname = userInfo.nickname
        let oldIdentifier = userInfo.identifier
        let oldBirthday = userInfo.birthday
        
        let updater1 = PUserInfo.Updater(userInfoId: userInfo.id)
            .update(nickname: "NewNick")
            .update(identifier: "NewId-123")
            .update(birthday: Date())
        _ = try await s.userInfo.update(with: updater1)
        
        let updater2 = PUserInfo.Updater(userInfoId: userInfo.id)
            .update(nickname: { _ in oldNickname })
            .update(identifier: { _ in oldIdentifier })
            .update(birthday: { _ in oldBirthday })
        _ = try await s.userInfo.update(with: updater2)
    }
    
    @Test("QInfoSlice.Updater 测试")
    func testInfoSliceUpdater() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let slices = try await s.query(QInfoSlice<AlternateEmail>.self).limit(1).all()
        guard let slice = slices.first else { return }
        
        let oldValue = slice.value
        let oldOrder = slice.order
        let oldDesc = slice.summary
        
        let updater1 = PInfoSlice<AlternateEmail>.Updater(infoSliceId: slice.id)
            .update(value: "new_alt@example.com")
            .update(order: 99)
            .update(summary: "NewDesc")
        _ = try await s.infoSlice.update(with: updater1)
        
        let updater2 = PInfoSlice<AlternateEmail>.Updater(infoSliceId: slice.id)
            .update(value: { _ in oldValue })
            .update(order: { _ in oldOrder })
            .update(summary: { _ in oldDesc })
        _ = try await s.infoSlice.update(with: updater2)
    }
}
