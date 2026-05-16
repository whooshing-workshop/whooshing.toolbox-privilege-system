import Cryptos
import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
import Query
import Collections
@testable import PrivilegeSystem
@testable import PrivilegeModule

@Suite("各模型关系 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct RelationsTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .relations {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("构建 User 与 Group 关系")
    func buildUserInGroups() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allUsers = try await s.query(QUser.self).all().get()
        let allGroups = try await s.query(QGroup.self).all().get()
        
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        // 遍历 TestingShared.userInGroups 并绑定
        for (userIdx, groupIndices) in TestingShared.userInGroups {
            let user = users[userIdx]
            let mappedGroups = groupIndices.map { groups[$0] }
            
            if !mappedGroups.isEmpty {
                try await s.group.join {
                    [user] => mappedGroups
                }.get()
            }
        }
        
        // 验证数据库
        let expectedCount = TestingShared.userInGroups.values.reduce(0) { $0 + $1.count }
        let actualCount = try await UserGroupPivot.query(on: s.db).count().get()
        #expect(actualCount == expectedCount, "UserGroupPivot 表数据量应与映射配置匹配")
    }

    @Test("构建群组嵌套结构（embed）")
    func buildGroupStructures() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allGroups = try await s.query(QGroup.self).all().get()

        // 通过 GroupTesting.ids 索引精确映射
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }

        for (parentIdx, childIndices) in TestingShared.groupStructures {
            guard !childIndices.isEmpty else { continue }
            let parent = groups[parentIdx]
            let children = childIndices.map { groups[$0] }

            // embed: [children] => parent
            try await s.group.embed {
                children => parent
            }.get()
        }

        // 验证：逐父群组检查子群组数量（用 QGroup DTO query 过滤 parentId）
        for (parentIdx, childIndices) in TestingShared.groupStructures {
            let parentId = groups[parentIdx].id
            let childCount = try await s.query(QGroup.self)
                .filter(\.parentId == parentId)
                .count().get()
            #expect(childCount == childIndices.count,
                    "GT.ids[\(parentIdx)] 应有 \(childIndices.count) 个子群组，实际 \(childCount) 个")
        }
    }
    
    @Test("构建 Domain 与 Group 关系")
    func buildDomainForGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allDomains = try await s.query(QDomain.self).all().get()
        let allGroups = try await s.query(QGroup.self).all().get()
        
        let domains = DomainTesting.ids.compactMap { id in allDomains.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        for (domainIdx, groupIndices) in TestingShared.domainForGroup {
            let domain = domains[domainIdx]
            let mappedGroups = groupIndices.map { groups[$0] }
            
            if !mappedGroups.isEmpty {
                try await s.domain.assign {
                    [domain] => mappedGroups
                }.get()
            }
        }
        
        let expectedCount = TestingShared.domainForGroup.values.reduce(0) { $0 + $1.count }
        let actualCount = try await DomainGroupPivot.query(on: s.db).count().get()
        #expect(actualCount == expectedCount, "DomainGroupPivot 表数据量应与映射配置匹配")
    }
    
    @Test("构建 Domain 与 User 关系")
    func buildDomainForUser() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all().get()
        let domains = try await s.query(QDomain.self).all().get()
        
        for (domainIdx, userIndices) in TestingShared.domainForUser {
            let domain = domains[domainIdx]
            let mappedUsers = userIndices.map { users[$0] }
            
            if !mappedUsers.isEmpty {
                try await s.domain.assign {
                    [domain] => mappedUsers
                }.get()
            }
        }
        
        let expectedCount = TestingShared.domainForUser.values.reduce(0) { $0 + $1.count }
        let actualCount = try await UserDomainPivot.query(on: s.db).count().get()
        #expect(actualCount == expectedCount, "UserDomainPivot 表数据量应与映射配置匹配")
    }
    
    @Test("构建 Role 与 User/Group 关系")
    func buildRoleForUserAndGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allRoles = try await s.query(QRole.self).all().get()
        let allUsers = try await s.query(QUser.self).all().get()
        let allGroups = try await s.query(QGroup.self).all().get()
        
        let roles = RoleTesting.ids.compactMap { id in allRoles.first(where: { $0.id == id }) }
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        // 分配给 User
        for (roleIdx, userIndices) in TestingShared.roleForUser {
            let role = roles[roleIdx]
            let mappedUsers = userIndices.map { users[$0] }
            
            if !mappedUsers.isEmpty {
                try await s.role.appoint {
                    [role] => mappedUsers
                }.get()
            }
        }
        
        // 分配给 Group
        for (roleIdx, groupIndices) in TestingShared.roleForGroup {
            let role = roles[roleIdx]
            let mappedGroups = groupIndices.map { groups[$0] }
            
            if !mappedGroups.isEmpty {
                try await s.role.appoint {
                    [role] => mappedGroups
                }.get()
            }
        }
    }
    
    @Test("构建 Role 与 组内用户 (UserInGroup) 的关系")
    func buildRoleForGroupUser() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allRoles = try await s.query(QRole.self).all().get()
        let allUsers = try await s.query(QUser.self).all().get()
        let allGroups = try await s.query(QGroup.self).all().get()
        
        let roles = RoleTesting.ids.compactMap { id in allRoles.first(where: { $0.id == id }) }
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        for (roleIdx, mappings) in TestingShared.roleForGroupUser {
            let role = roles[roleIdx]
            
            for (userIdx, groupIdx) in mappings {
                let user = users[userIdx]
                let group = groups[groupIdx]
                
                // 首先我们需要先在系统里检索他们的关系对 (UserInGroupRelation)
                let relReq = try await s.group.query(
                    relations: [
                        user =| group
                    ]
                ).get()
                
                if let rel = relReq.first(where: { $0.user.id == user.id && $0.group.id == group.id }) {
                    try await s.role.appoint {
                        [role] => [rel]
                    }.get()
                }
            }
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .policy
    }
}
