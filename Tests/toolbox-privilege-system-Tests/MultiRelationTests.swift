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

@Suite("批量模型关系 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct MultiRelationsTesting {
    
//    @Test("开始测试")
//    func start() async throws {
//        while await TestingShared.testStage != .multiRelations {
//            try await Task.sleep(nanoseconds: 250_000_000)
//        }
//    }
    
    static let roles: [PRole] = [
        .init(id: UUID(), name: "MRT-ROLE1", description: "批量测试角色 1"),
        .init(id: UUID(), name: "MRT-ROLE2", description: "批量测试角色 2"),
        .init(id: UUID(), name: "MRT-ROLE3", description: "批量测试角色 3"),
        .init(id: UUID(), name: "MRT-ROLE4", description: "批量测试角色 4"),
        .init(id: UUID(), name: "MRT-ROLE5", description: "批量测试角色 5"),
        .init(id: UUID(), name: "MRT-ROLE6", description: "批量测试角色 6"),
        .init(id: UUID(), name: "MRT-ROLE7", description: "批量测试角色 7"),
        .init(id: UUID(), name: "MRT-ROLE8", description: "批量测试角色 8"),
        .init(id: UUID(), name: "MRT-ROLE9", description: "批量测试角色 9")
    ]
    
    static let groups: [PGroup] = [
        .init(id: UUID(), name: "MRT-GROUP1", description: "批量测试群组 1"),
        .init(id: UUID(), name: "MRT-GROUP2", description: "批量测试群组 2"),
        .init(id: UUID(), name: "MRT-GROUP3", description: "批量测试群组 3"),
        .init(id: UUID(), name: "MRT-GROUP4", description: "批量测试群组 4"),
        .init(id: UUID(), name: "MRT-GROUP5", description: "批量测试群组 5"),
        .init(id: UUID(), name: "MRT-GROUP6", description: "批量测试群组 6"),
        .init(id: UUID(), name: "MRT-GROUP7", description: "批量测试群组 7"),
        .init(id: UUID(), name: "MRT-GROUP8", description: "批量测试群组 8"),
        .init(id: UUID(), name: "MRT-GROUP9", description: "批量测试群组 9")
    ]
    
    @Test("创建 Roles 与 Groups")
    func creates() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let roles = try await s.role.create(roles: Self.roles)
        let groups = try await s.group.create(groups: Self.groups)
        
        #expect(roles.enumerated().allSatisfy { $0.element.id == Self.roles[$0.offset].id! })
        #expect(groups.enumerated().allSatisfy { $0.element.id == Self.groups[$0.offset].id! })
        
        let roleIds = Self.roles.map { $0.id! }
        let groupIds = Self.groups.map { $0.id! }
        
        #expect(try await s.query(QRole.self).filter(\.id ~~ roleIds).count() == Self.roles.count)
        #expect(try await s.query(QGroup.self).filter(\.id ~~ groupIds).count() == Self.groups.count)
    }
    
    @Test("正常多对多创建")
    func normalRelations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let roleIds = [Self.roles[0].id!, Self.roles[1].id!, Self.roles[2].id!]
        let groupIds = [Self.groups[0].id!, Self.groups[1].id!, Self.groups[2].id!]
        
        try await s.role.appoint(roleToGroup: {
            roleIds => groupIds
        })
        
        var count = try await s.query(RoleTGroup.self)
            .filter(\.roleId ~~ roleIds)
            .filter(\.groupId ~~ groupIds)
            .count()
        
        #expect(count == roleIds.count * groupIds.count)
        
        try await s.role.dismiss(roleFromGroup: {
            roleIds => groupIds
        })
        
        count = try await s.query(RoleTGroup.self)
            .filter(\.roleId ~~ roleIds)
            .filter(\.groupId ~~ groupIds)
            .count()
        
        #expect(count == 0)
    }
    
    // 正常多对多创建
    // 使用重复的 id 进行创建
    // 使用不存在的 id 进行创建
    // 使用未存储的 UUID 创建
    // 删除不存在的关系
    
    @Test("使用重复的 id 进行创建")
    func duplicatedIdRelations() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let roleIds = [Self.roles[0].id!, Self.roles[0].id!, Self.roles[0].id!]
        let groupIds = [Self.groups[0].id!, Self.groups[0].id!, Self.groups[0].id!]
        
        try await s.role.appoint(roleToGroup: {
            roleIds => groupIds
        })
        
        var count = try await s.query(RoleTGroup.self)
            .filter(\.roleId ~~ roleIds)
            .filter(\.groupId ~~ groupIds)
            .count()
        
        #expect(count == 1)
        
        try await s.role.dismiss(roleFromGroup: {
            roleIds => groupIds
        })
        
        count = try await s.query(RoleTGroup.self)
            .filter(\.roleId ~~ roleIds)
            .filter(\.groupId ~~ groupIds)
            .count()
        
        #expect(count == 0)
    }
    
    @Test("销毁 Roles 与 Groups")
    func deletes() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let roleIds = Self.roles.map { $0.id! }
        let groupIds = Self.groups.map { $0.id! }
        try await s.role.delete(roleIds: roleIds)
        try await s.group.delete(groupIds: groupIds)
        
        #expect(try await s.query(QRole.self).filter(\.id ~~ roleIds).first() == nil)
        #expect(try await s.query(QGroup.self).filter(\.id ~~ groupIds).first() == nil)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
