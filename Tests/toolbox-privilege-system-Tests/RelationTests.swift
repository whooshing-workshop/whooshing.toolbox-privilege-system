import Cryptos
import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
import Query
import Collections
import Fluent
import Policy
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

    private func fetchUser(index: Int, s: PrivilegeSystem) async throws -> QUser {
        let model = try await __SDBM.User.query(on: s.db)
            .filter(\.$id == AccountTesting.ids[index])
            .with(\.$groups)
            .first()
            
        return try QUser.make(from: try #require(model)).get()
    }

    private func fetchRole(index: Int, s: PrivilegeSystem) async throws -> QRole {
        try #require(
            try await s.query(QRole.self)
                .filter(\.id == RT.ids[index])
                .first()
        )
    }
    
    @Test("构建 User 与 Group 关系")
    func buildUserInGroups() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allUsers = try await s.query(QUser.self).all()
        let allGroups = try await s.query(QGroup.self).all()

        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        // 遍历 TestingShared.userInGroups 并绑定
        for (userIdx, groupIndices) in TestingShared.userInGroups {
            let user = users[userIdx]
            let mappedGroups = groupIndices.map { groups[$0] }
            
            if !mappedGroups.isEmpty {
                try await s.group.join {
                    [user] => mappedGroups
                }
            }
        }
        
        // 验证数据库
        let expectedCount = TestingShared.userInGroups.values.reduce(0) { $0 + $1.count }
        let actualCount = try await __SDBM.UserGroupPivot.query(on: s.db).count()
        #expect(actualCount == expectedCount, "UserGroupPivot 表数据量应与映射配置匹配")
    }

    @Test("构建群组嵌套结构（move）")
    func buildGroupStructures() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allGroups = try await s.query(QGroup.self).all()

        // 通过 GroupTesting.ids 索引精确映射
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }

        for (parentIdx, childIndices) in TestingShared.groupStructures {
            guard !childIndices.isEmpty else { continue }
            let parent = groups[parentIdx]

            for childIdx in childIndices {
                let child = groups[childIdx]
                // move: child => Optional(parent) 建立父子关系
                try await s.group.move(child => Optional(parent))
            }
        }

        // 验证：用 QGroup.parentId 确认每个子群组已成功挂载到父群组下
        for (parentIdx, childIndices) in TestingShared.groupStructures {
            let parentId = groups[parentIdx].id
            let childCount = try await s.query(QGroup.self)
                .filter(\.parentId == parentId)
                .count()
            #expect(childCount == childIndices.count,
                    "GT.ids[\(parentIdx)] 应有 \(childIndices.count) 个直接子群组，实际 \(childCount) 个")
        }
    }
    
    @Test("构建 Domain 与 Group 关系")
    func buildDomainForGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allDomains = try await s.query(QDomain.self).all()
        let allGroups = try await s.query(QGroup.self).all()
        
        let domains = DomainTesting.ids.compactMap { id in allDomains.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        for (domainIdx, groupIndices) in TestingShared.domainForGroup {
            let domain = domains[domainIdx]
            let mappedGroups = groupIndices.map { groups[$0] }
            
            if !mappedGroups.isEmpty {
                try await s.domain.assign {
                    [domain] => mappedGroups
                }
            }
        }
        
        let expectedCount = TestingShared.domainForGroup.values.reduce(0) { $0 + $1.count }
        let actualCount = try await __SDBM.DomainGroupPivot.query(on: s.db).count()
        #expect(actualCount == expectedCount, "DomainGroupPivot 表数据量应与映射配置匹配")
    }
    
    @Test("构建 Domain 与 __SDBM.User 关系")
    func buildDomainForUser() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allUsers = try await s.query(QUser.self).all()
        let allDomains = try await s.query(QDomain.self).all()
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let domains = DomainTesting.ids.compactMap { id in allDomains.first(where: { $0.id == id }) }
        for (domainIdx, userIndices) in TestingShared.domainForUser {
            let domain = domains[domainIdx]
            let mappedUsers = userIndices.map { users[$0] }
            
            if !mappedUsers.isEmpty {
                try await s.domain.assign {
                    [domain] => mappedUsers
                }
            }
        }
        
        let expectedCount = TestingShared.domainForUser.values.reduce(0) { $0 + $1.count }
        let actualCount = try await __SDBM.UserDomainPivot.query(on: s.db).count()
        #expect(actualCount == expectedCount, "UserDomainPivot 表数据量应与映射配置匹配")
    }
    
    @Test("构建 Role 与 __SDBM.User/Group 关系")
    func buildRoleForUserAndGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allRoles = try await s.query(QRole.self).all()
        let allUsers = try await s.query(QUser.self).all()
        let allGroups = try await s.query(QGroup.self).all()
        
        let roles = RoleTesting.ids.compactMap { id in allRoles.first(where: { $0.id == id }) }
        let users = AccountTesting.ids.compactMap { id in allUsers.first(where: { $0.id == id }) }
        let groups = GroupTesting.ids.compactMap { id in allGroups.first(where: { $0.id == id }) }
        
        // 分配给 __SDBM.User
        for (roleIdx, userIndices) in TestingShared.roleForUser {
            let role = roles[roleIdx]
            let mappedUsers = userIndices.map { users[$0] }
            
            if !mappedUsers.isEmpty {
                try await s.role.appoint {
                    [role] => mappedUsers
                }
            }
        }
        
        // 分配给 Group
        for (roleIdx, groupIndices) in TestingShared.roleForGroup {
            let role = roles[roleIdx]
            let mappedGroups = groupIndices.map { groups[$0] }
            
            if !mappedGroups.isEmpty {
                try await s.role.appoint {
                    [role] => mappedGroups
                }
            }
        }
    }
    
    @Test("构建 Role 与 组内用户 (UserInGroup) 的关系")
    func buildRoleForGroupUser() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allRoles = try await s.query(QRole.self).all()
        let allUsers = try await s.query(QUser.self).all()
        let allGroups = try await s.query(QGroup.self).all()
        
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
                )
                
                if let rel = relReq.first(where: { $0.user.id == user.id && $0.group.id == group.id }) {
                    try await s.role.appoint {
                        [role] => [rel]
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: RoleController relation query API
    // =========================================================================

    @Test("RoleController：roles(for:) 返回用户所有可用角色的并集")
    func roleAPI_roles_ReturnsAllAvailableRoles() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user0: RT[0](用户角色) + RT[3](组内角色 in group0) + RT[11](group0 群组角色)
        let user = try await fetchUser(index: 0, s: s)
        let allRoles = try await s.role.roles(for: user)
        let allRoleIds = Set(allRoles.map { $0.id })
        #expect(allRoleIds.contains(RT.ids[0]), "用户角色 RT[0] 应包含在内")
        #expect(allRoleIds.contains(RT.ids[3]), "组内角色 RT[3] 应包含在内")
        #expect(allRoleIds.contains(RT.ids[11]), "群组角色 RT[11] 应包含在内")
    }

    @Test("RoleController：userRoles(for:) 仅返回直接赋予用户的角色")
    func roleAPI_userRoles_ReturnsOnlyDirectUserRoles() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user1: RT[1](Editor), RT[3](Observer) 均为用户角色
        let user = try await fetchUser(index: 1, s: s)
        let userRoles = try await s.role.userRoles(for: user)
        let ids = Set(userRoles.map { $0.id })
        #expect(ids.contains(RT.ids[1]), "user1 的用户角色应包含 RT[1](Editor)")
        #expect(ids.contains(RT.ids[3]), "user1 的用户角色应包含 RT[3](Observer)")
        #expect(!ids.contains(RT.ids[5]), "userRoles(for:) 不应返回群组角色")
    }

    @Test("RoleController：groupRoles(for:) 返回用户所有群组及父群组角色")
    func roleAPI_groupRoles_IncludesDirectAndParentGroupRoles() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user3 在 group3(BannedUsers)，group3 绑 RT[5] 为直接群组角色。
        let user3 = try await fetchUser(index: 3, s: s)
        let directGroupRoles = try await s.role.groupRoles(for: user3)
        let directRoleIds = Set(directGroupRoles.flatMap { $0.left.map { $0.id } })
        #expect(directRoleIds.contains(RT.ids[5]), "group3 的群组角色 RT[5] 应被查到")

        // user6 在 group6/group7，二者都是 group0 子群组；RT[11] 绑在父群组 group0。
        let user6 = try await fetchUser(index: 6, s: s)
        let inheritedGroupRoles = try await s.role.groupRoles(for: user6)
        let inheritedRoleIds = Set(inheritedGroupRoles.flatMap { $0.left.map { $0.id } })
        #expect(inheritedRoleIds.contains(RT.ids[11]), "父群组 group0 的群组角色 RT[11] 应被继承查到")
    }

    @Test("RoleController：userInGroupRoles(for:) 返回用户在各群组内的专属角色")
    func roleAPI_userInGroupRoles_ReturnsInGroupRoles() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user0 在 group0 中有组内角色 RT[3]
        let user = try await fetchUser(index: 0, s: s)
        let inGroupRoles = try await s.role.userInGroupRoles(for: user)
        let allRoleIds = Set(inGroupRoles.flatMap { $0.left.map { $0.id } })
        #expect(allRoleIds.contains(RT.ids[3]), "user0 在 group0 的组内角色 RT[3] 应被查到")
    }

    @Test("RoleController：is(role:appointedTo:) 对用户角色、群组角色、组内角色均返回 true")
    func roleAPI_is_role_ChecksAllThreeSources() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user0: RT[0](用户角色) + RT[11](群组角色) + RT[3](组内角色)
        let user = try await fetchUser(index: 0, s: s)
        let rt0 = try await fetchRole(index: 0, s: s)
        let rt3 = try await fetchRole(index: 3, s: s)
        let rt11 = try await fetchRole(index: 11, s: s)
        let rt1 = try await fetchRole(index: 1, s: s) // user0 没有 RT[1]

        #expect(try await s.role.is(role: rt0, appointedTo: user), "RT[0] 是 user0 的用户角色")
        #expect(try await s.role.is(role: rt3, appointedTo: user), "RT[3] 是 user0 的组内角色")
        #expect(try await s.role.is(role: rt11, appointedTo: user), "RT[11] 是 user0 的群组角色")
        #expect(!(try await s.role.is(role: rt1, appointedTo: user)), "RT[1] 不属于 user0")
    }

    @Test("RoleController：is(userRole:appointedTo:) 精确检查用户角色")
    func roleAPI_is_userRole_ExactCheck() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user1: RT[1](Editor), RT[3](Observer) 均为用户角色
        let user = try await fetchUser(index: 1, s: s)
        let rt1 = try await fetchRole(index: 1, s: s)
        let rt2 = try await fetchRole(index: 2, s: s) // user1 没有 RT[2]

        #expect(try await s.role.is(userRole: rt1, appointedTo: user), "RT[1] 是 user1 的用户角色")
        #expect(!(try await s.role.is(userRole: rt2, appointedTo: user)), "RT[2] 不是 user1 的用户角色")
    }

    @Test("RoleController：is(groupRole:appointedTo:) 精确检查群组角色")
    func roleAPI_is_groupRole_ExactCheck() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // group3(BannedUsers) 绑 RT[5] 为群组角色
        let allGroups = try await s.query(QGroup.self).all()
        let group3 = try #require(allGroups.first(where: { $0.id == GT.ids[3] }))
        let rt5 = try await fetchRole(index: 5, s: s)
        let rt1 = try await fetchRole(index: 1, s: s)

        #expect(try await s.role.is(groupRole: rt5, appointedTo: group3), "RT[5] 是 group3 的群组角色")
        #expect(!(try await s.role.is(groupRole: rt1, appointedTo: group3)), "RT[1] 不是 group3 的群组角色")
    }

    @Test("RoleController：verify(groupRole:appointedTo:) 返回该群组角色适用的群组列表")
    func roleAPI_verify_groupRole_ReturnsApplicableGroups() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user3 在 group3(BannedUsers)，group3 是 RT[5] 的群组角色持有者
        let user = try await fetchUser(index: 3, s: s)
        let rt5 = try await fetchRole(index: 5, s: s)

        let groups = try await s.role.verify(groupRole: rt5, appointedTo: user)
        #expect(!groups.isEmpty, "RT[5] 作为群组角色，应返回包含 group3 的群组列表")
        let groupIds = Set(groups.map { $0.id })
        #expect(groupIds.contains(GT.ids[3]), "group3 应在返回列表中")
    }

    @Test("RoleController：verify(userInGroupRole:appointedTo:) 返回该组内角色适用的群组列表")
    func roleAPI_verify_userInGroupRole_ReturnsApplicableGroups() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user0 在 group0 中有组内角色 RT[3]
        let user = try await fetchUser(index: 0, s: s)
        let rt3 = try await fetchRole(index: 3, s: s)

        let groups = try await s.role.verify(userInGroupRole: rt3, appointedTo: user)
        #expect(!groups.isEmpty, "RT[3] 作为 user0 的组内角色，应返回包含 group0 的群组列表")
        let groupIds = Set(groups.map { $0.id })
        #expect(groupIds.contains(GT.ids[0]), "group0 应在返回列表中")
    }

    @Test("RoleController：verify(userInGroupRole:) 对无组内角色的用户返回空列表")
    func roleAPI_verify_userInGroupRole_EmptyForNoAssignment() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user4 无任何组内角色指派
        let user = try await fetchUser(index: 4, s: s)
        let rt3 = try await fetchRole(index: 3, s: s)

        let groups = try await s.role.verify(userInGroupRole: rt3, appointedTo: user)
        #expect(groups.isEmpty, "user4 无组内角色，应返回空列表")
    }

    @Test("RoleController：roles(for:) 不重复返回角色")
    func roleAPI_roles_Deduplication() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // user8: RT[12], RT[13](用户角色) + RT[6](group10 群组角色和组内角色)
        let user = try await fetchUser(index: 8, s: s)
        let roles = try await s.role.roles(for: user)
        let ids = roles.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "roles(for:) 不应返回重复角色")
        #expect(uniqueIds.contains(RT.ids[12]), "RT[12] 应包含在内")
        #expect(uniqueIds.contains(RT.ids[13]), "RT[13] 应包含在内")
        #expect(uniqueIds.contains(RT.ids[6]), "RT[6] 应以去重后的形式包含在内")
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .query
    }
}
