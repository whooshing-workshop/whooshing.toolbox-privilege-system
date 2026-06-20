import Testing
import Foundation
@testable import PrivilegeSystem

@Suite("Concurrency 与 Closure 重载测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct ConcurrencyAndClosureTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .query {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("DomainController closure & async API")
    func testDomainConcurrency() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await s.query(QUser.self).limit(1).all()
        let groups = try await s.query(QGroup.self).limit(1).all()
        guard let user = users.first, let group = groups.first else { return }
        
        // create domain
        _ = try await s.domain.create(domains: [PDomain(name: "TempDomain", summary: "Temp")])
        
        let tempDomain = try await s.query(QDomain.self).filter(\.name == "TempDomain").first()!
        
        // assign closure & async
        try await s.domain.assign(domainToUser: [MTMRelation(left: [tempDomain.id], right: [user.id])])
        try await s.domain.assign(domainToGroup: [MTMRelation(left: [tempDomain.id], right: [group.id])])
        
        // unassign
        try await s.domain.unassign(domainFromUser: [MTMRelation(left: [tempDomain.id], right: [user.id])])
        try await s.domain.unassign(domainFromGroup: [MTMRelation(left: [tempDomain.id], right: [group.id])])
    }
    
    @Test("RoleController closure & async API")
    func testRoleConcurrency() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await s.query(QUser.self).limit(1).all()
        let groups = try await s.query(QGroup.self).limit(1).all()
        guard let user = users.first, let group = groups.first else { return }
        
        // create closure
        _ = try await s.role.create(roles: [PRole(name: "TempRole", summary: "Temp")])
        
        let tempRole = try await s.query(QRole.self).filter(\.name == "TempRole").first()!
        
        // appoint closure
        try await s.role.appoint(roleToUser: [MTMRelation(left: [tempRole.id], right: [user.id])])
        try await s.role.appoint(roleToGroup: [MTMRelation(left: [tempRole.id], right: [group.id])])
        
        // appoint to userInGroup (for async coverage)
        let utgs = try await s.query(UserTGroup.self).all()
        var targetUtgId: UUID? = nil
        for utg in utgs {
            if utg.userId == user.id && utg.groupId == group.id {
                targetUtgId = utg.id
                break
            }
        }
        if let utgId = targetUtgId {
            try await s.role.appoint(roleToUserInGroup: [MTMRelation(left: [tempRole.id], right: [utgId])])
            try await s.role.dismiss(roleFromUserInGroup: [MTMRelation(left: [tempRole.id], right: [utgId])])
        }
        
        // dismiss
        try await s.role.dismiss(roleFromUser: [MTMRelation(left: [tempRole.id], right: [user.id])])
        try await s.role.dismiss(roleFromGroup: [MTMRelation(left: [tempRole.id], right: [group.id])])
    }
    
    @Test("GroupController async API")
    func testGroupConcurrency() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await s.query(QUser.self).limit(1).all()
        guard let user = users.first else { return }
        
        // create closure
        _ = try await s.group.create(groups: [PGroup(name: "TempGroup", parentId: nil, summary: "Temp")])
        
        let tempGroup = try await s.query(QGroup.self).filter(\.name == "TempGroup").first()!
        
        // add users
        try await s.group.join(userToGroup: [MTMRelation(left: [user.id], right: [tempGroup.id])])
        try await s.group.kick(userFromGroup: [MTMRelation(left: [user.id], right: [tempGroup.id])])
    }
    

}

