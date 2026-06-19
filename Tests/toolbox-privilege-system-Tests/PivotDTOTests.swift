import Testing
import Foundation
import Fluent
import Query
import OrderedCollections
@preconcurrency import AnyCodable
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import DTOBuilder

// ---------------------------------------------------------------------------
// PivotDTOTests.swift
//
// 对 PrivilegeSystem 侧的六种 Pivot DTO 以及 PrivilegeModule 侧的
// PrivilegeTAnyResource / PrivilegeTResource<G> 做全面覆盖：
//
//   PrivilegeSystem 侧:
//     UserTRole         - (User, Role)         多对多用户-角色直接分配
//     UserTGroup        - (User, Group)         多对多用户-群组隶属
//     UserTDomain       - (User, Domain)        多对多用户-域直接分配
//     RoleTGroup        - (Role, Group)         多对多角色-群组分配
//     RoleTUserInGroup  - (Role, UserTGroup)    组内用户的专属角色
//     DomainTGroup      - (Domain, Group)       多对多域-群组分配
//
//   PrivilegeModule 侧:
//     PM.PrivilegeTAnyResource  - (Privilege, AnyResource)
//     PM.PrivilegeTResource<G>  - (Privilege, QResource<G>)
//
// 测试维度：
//   1. 字段映射正确性（id、primaryId 别名、secondaryId 别名、createdAt）
//   2. 通过 primaryId 字段过滤精确查询
//   3. 通过 secondaryId 字段过滤精确查询
//   4. `~~` in-list 批量过滤与计数
//   5. @Sibling 双向反向关联加载
//   6. 关系建立/解除前后的计数变化
// ---------------------------------------------------------------------------

@Suite("Pivot DTO 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct PivotDTOTesting {

    // MARK: - 生命周期

    @Test("Pivot DTO 全流程测试")
    func runAll() async throws {
        try await start()
        try await test_UserTRole()
        try await test_UserTGroup()
        try await test_UserTDomain()
        try await test_RoleTGroup()
        try await test_RoleTUserInGroup()
        try await test_DomainTGroup()
        try await test_PrivilegeTAnyResource()
        try await test_PrivilegeTResource()
        try await end()
    }

    func start() async throws {
        while await TestingShared.testStage != .pivotDTO {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    @MainActor
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }

    // MARK: - 辅助

    // 从 SharedData 中确认的关系（由 RelationTests 建立）：
    //   roleForUser[0]       = [0]    → RT[0] (SuperAdminRole) → AT[0]
    //   roleForUser[1]       = [1]    → RT[1] (EditorRole)     → AT[1]
    //   userInGroups[0]      = [0]    → AT[0] → GT[0] (AdministratorGroup)
    //   userInGroups[1]      = [1]    → AT[1] → GT[1] (OperatorGroup)
    //   domainForUser[0]     = [0]    → DT[0] (GlobalScope) → AT[0]
    //   domainForGroup[0]    = [0]    → DT[0] → GT[0]
    //   roleForGroup[11]     = [0]    → RT[11] (ProductManager) → GT[0]
    //   roleForGroupUser[3]  = [(0,0)]→ RT[3] (ObserverRole) → AT[0] in GT[0]

    // MARK: - UserTRole

    func test_UserTRole() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // 1. 通过 userId 过滤 —— AT[0] 应持有 RT[0]
        let byUser = try await s.query(UserTRole.self)
            .filter(\.userId == AT.ids[0])
            .all()
        #expect(!byUser.isEmpty, "AT[0] 至少应有一条 UserTRole 记录")
        #expect(byUser.contains { $0.roleId == RT.ids[0] }, "AT[0] 应持有 RT[0]")

        // 2. 通过 roleId 过滤 —— RT[0] 应归属 AT[0]
        let byRole = try await s.query(UserTRole.self)
            .filter(\.roleId == RT.ids[0])
            .all()
        #expect(!byRole.isEmpty, "RT[0] 至少应有一条 UserTRole 记录")
        #expect(byRole.contains { $0.userId == AT.ids[0] }, "RT[0] 应归属 AT[0]")

        // 3. 字段映射正确性 —— primaryId / secondaryId 是计算属性别名
        let pivot = try #require(byUser.first { $0.roleId == RT.ids[0] })
        #expect(pivot.primaryId == pivot.userId,   "primaryId 应等价于 userId")
        #expect(pivot.secondaryId == pivot.roleId, "secondaryId 应等价于 roleId")
        #expect(pivot.userId == AT.ids[0])
        #expect(pivot.roleId == RT.ids[0])

        // 4. 批量 in 查询
        let roleIds: [UUID] = [RT.ids[0], RT.ids[1]]
        let batchCount = try await s.query(UserTRole.self)
            .filter(\.roleId ~~ roleIds)
            .count()
        #expect(batchCount >= 2, "RT[0] 和 RT[1] 各至少有一条用户分配记录")

        // 5. id 精确查询
        let viaId = try await s.query(UserTRole.self)
            .filter(\.id == pivot.id)
            .first()
        #expect(viaId != nil,              "通过 id 应能精确检索 pivot 记录")
        #expect(viaId?.id == pivot.id)
    }

    // MARK: - UserTGroup

    func test_UserTGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // 1. 通过 userId 过滤
        let byUser = try await s.query(UserTGroup.self)
            .filter(\.userId == AT.ids[0])
            .all()
        #expect(!byUser.isEmpty, "AT[0] 至少应有一条 UserTGroup 记录")
        #expect(byUser.contains { $0.groupId == GT.ids[0] }, "AT[0] 应属于 GT[0]")

        // 2. 通过 groupId 过滤
        let byGroup = try await s.query(UserTGroup.self)
            .filter(\.groupId == GT.ids[0])
            .all()
        #expect(!byGroup.isEmpty, "GT[0] 至少应有一条 UserTGroup 记录")
        #expect(byGroup.contains { $0.userId == AT.ids[0] }, "GT[0] 应包含 AT[0]")

        // 3. 字段映射正确性
        let pivot = try #require(byUser.first { $0.groupId == GT.ids[0] })
        #expect(pivot.primaryId == pivot.userId,   "primaryId 应等价于 userId")
        #expect(pivot.secondaryId == pivot.groupId, "secondaryId 应等价于 groupId")

        // 4. id 精确查询
        let viaId = try await s.query(UserTGroup.self)
            .filter(\.id == pivot.id)
            .first()
        #expect(viaId?.id == pivot.id)

        // 5. @Sibling $roles —— AT[0] 在 GT[0] 中被分配了 RT[3] (ObserverRole)
        //    roleForGroupUser[3] = [(0, 0)]: RT[3] → AT[0] in GT[0]
        try await pivot.$roles.load(on: s).get()
        #expect(pivot.$roles.loaded == true, "$roles 应已成功加载")
        #expect(pivot.roles.contains { $0.id == RT.ids[3] },
                "AT[0] 在 GT[0] 中的 UserTGroup 应包含组内角色 RT[3]")

        // 6. 批量 in 查询
        let groupIds: [UUID] = [GT.ids[0], GT.ids[1]]
        let batchCount = try await s.query(UserTGroup.self)
            .filter(\.groupId ~~ groupIds)
            .count()
        #expect(batchCount >= 2, "GT[0] 和 GT[1] 各至少有一名成员")
    }

    // MARK: - UserTDomain

    func test_UserTDomain() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // domainForUser[0] = [0] → DT[0] → AT[0]
        // 1. 通过 userId 过滤
        let byUser = try await s.query(UserTDomain.self)
            .filter(\.userId == AT.ids[0])
            .all()
        #expect(!byUser.isEmpty, "AT[0] 至少应有一条 UserTDomain 记录")
        #expect(byUser.contains { $0.domainId == DT.ids[0] }, "AT[0] 应直属 DT[0]")

        // 2. 通过 domainId 过滤
        let byDomain = try await s.query(UserTDomain.self)
            .filter(\.domainId == DT.ids[0])
            .all()
        #expect(!byDomain.isEmpty, "DT[0] 至少应直接分配一名用户")
        #expect(byDomain.contains { $0.userId == AT.ids[0] }, "DT[0] 应直接含 AT[0]")

        // 3. 字段映射正确性
        let pivot = try #require(byUser.first { $0.domainId == DT.ids[0] })
        #expect(pivot.primaryId == pivot.userId,    "primaryId 应等价于 userId")
        #expect(pivot.secondaryId == pivot.domainId, "secondaryId 应等价于 domainId")

        // 4. id 精确查询
        let viaId = try await s.query(UserTDomain.self)
            .filter(\.id == pivot.id)
            .first()
        #expect(viaId?.id == pivot.id)

        // 5. 批量 in 查询
        // domainForUser: 0=[0] → DT[0]→AT[0]; 4=[3] → DT[4]→AT[3]
        let domainIds: [UUID] = [DT.ids[0], DT.ids[4]]
        let batchCount = try await s.query(UserTDomain.self)
            .filter(\.domainId ~~ domainIds)
            .count()
        #expect(batchCount >= 2, "DT[0] 和 DT[4] 各至少分配一名用户")
    }

    // MARK: - RoleTGroup

    func test_RoleTGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // roleForGroup[11] = [0] → RT[11] (ProductManager) → GT[0]
        // roleForGroup[5]  = [3] → RT[5]  (HRLead)        → GT[3]
        // 1. 通过 roleId 过滤
        let byRole = try await s.query(RoleTGroup.self)
            .filter(\.roleId == RT.ids[11])
            .all()
        #expect(!byRole.isEmpty, "RT[11] 至少应分配给一个群组")
        #expect(byRole.contains { $0.groupId == GT.ids[0] }, "RT[11] 应分配给 GT[0]")

        // 2. 通过 groupId 过滤
        let byGroup = try await s.query(RoleTGroup.self)
            .filter(\.groupId == GT.ids[0])
            .all()
        #expect(!byGroup.isEmpty, "GT[0] 至少应有一个群组角色")
        #expect(byGroup.contains { $0.roleId == RT.ids[11] }, "GT[0] 应持有群组角色 RT[11]")

        // 3. 字段映射正确性
        let pivot = try #require(byRole.first { $0.groupId == GT.ids[0] })
        #expect(pivot.primaryId == pivot.roleId,   "primaryId 应等价于 roleId")
        #expect(pivot.secondaryId == pivot.groupId, "secondaryId 应等价于 groupId")

        // 4. id 精确查询
        let viaId = try await s.query(RoleTGroup.self)
            .filter(\.id == pivot.id)
            .first()
        #expect(viaId?.id == pivot.id)

        // 5. 批量 in 查询
        let roleIds: [UUID] = [RT.ids[11], RT.ids[5]]
        let batchCount = try await s.query(RoleTGroup.self)
            .filter(\.roleId ~~ roleIds)
            .count()
        #expect(batchCount >= 2, "RT[11] 和 RT[5] 各至少分配给一个群组")
    }

    // MARK: - RoleTUserInGroup

    func test_RoleTUserInGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // roleForGroupUser[3] = [(0, 0)] → RT[3] → AT[0] in GT[0]
        // 先找到 AT[0] 在 GT[0] 的 UserTGroup 记录
        let utg = try #require(
            try await s.query(UserTGroup.self)
                .filter(\.userId == AT.ids[0])
                .filter(\.groupId == GT.ids[0])
                .first(),
            "AT[0] 在 GT[0] 中的 UserTGroup 记录应存在"
        )

        // 1. 通过 roleId 过滤
        let byRole = try await s.query(RoleTUserInGroup.self)
            .filter(\.roleId == RT.ids[3])
            .all()
        #expect(!byRole.isEmpty, "RT[3] 至少应有一条组内分配记录")
        #expect(byRole.contains { $0.userInGroupId == utg.id },
                "RT[3] 应分配给 AT[0] 在 GT[0] 的 UserTGroup 记录")

        // 2. 通过 userInGroupId 过滤
        let byUIG = try await s.query(RoleTUserInGroup.self)
            .filter(\.userInGroupId == utg.id)
            .all()
        #expect(!byUIG.isEmpty, "该 UserTGroup 应至少被分配一个组内角色")
        #expect(byUIG.contains { $0.roleId == RT.ids[3] },
                "该 UserTGroup 应包含 RT[3]")

        // 3. 字段映射正确性
        let pivot = try #require(byRole.first { $0.userInGroupId == utg.id })
        #expect(pivot.primaryId == pivot.roleId,         "primaryId 应等价于 roleId")
        #expect(pivot.secondaryId == pivot.userInGroupId, "secondaryId 应等价于 userInGroupId")

        // 4. id 精确查询
        let viaId = try await s.query(RoleTUserInGroup.self)
            .filter(\.id == pivot.id)
            .first()
        #expect(viaId?.id == pivot.id)

        // 5. 多条组内角色记录的批量查询
        //    roleForGroupUser[3]=(0,0), [4]=(6,6), [5]=(7,8), [6]=(8,10), [7]=(9,11)
        //    共 5 条组内角色分配
        let totalCount = try await s.query(RoleTUserInGroup.self).count()
        #expect(totalCount >= 5, "全局 RoleTUserInGroup 应至少有 5 条记录")
    }

    // MARK: - DomainTGroup

    func test_DomainTGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // domainForGroup[0] = [0] → DT[0] (GlobalScope) → GT[0]
        // domainForGroup[1] = [1] → DT[1] (AsiaPacific) → GT[1]
        // 1. 通过 domainId 过滤
        let byDomain = try await s.query(DomainTGroup.self)
            .filter(\.domainId == DT.ids[0])
            .all()
        #expect(!byDomain.isEmpty, "DT[0] 至少应分配给一个群组")
        #expect(byDomain.contains { $0.groupId == GT.ids[0] }, "DT[0] 应分配给 GT[0]")

        // 2. 通过 groupId 过滤
        let byGroup = try await s.query(DomainTGroup.self)
            .filter(\.groupId == GT.ids[0])
            .all()
        #expect(!byGroup.isEmpty, "GT[0] 至少应归属一个域")
        #expect(byGroup.contains { $0.domainId == DT.ids[0] }, "GT[0] 应归属 DT[0]")

        // 3. 字段映射正确性
        let pivot = try #require(byDomain.first { $0.groupId == GT.ids[0] })
        #expect(pivot.primaryId == pivot.domainId,  "primaryId 应等价于 domainId")
        #expect(pivot.secondaryId == pivot.groupId,  "secondaryId 应等价于 groupId")

        // 4. id 精确查询
        let viaId = try await s.query(DomainTGroup.self)
            .filter(\.id == pivot.id)
            .first()
        #expect(viaId?.id == pivot.id)

        // 5. 批量 in 查询
        let domainIds: [UUID] = [DT.ids[0], DT.ids[1], DT.ids[2], DT.ids[3]]
        let batchCount = try await s.query(DomainTGroup.self)
            .filter(\.domainId ~~ domainIds)
            .count()
        // domainForGroup[0]=[0],[1]=[1],[2]=[2],[3]=[3] → 各1条 → 至少4条
        #expect(batchCount >= 4, "DT[0~3] 合计应至少有 4 条域-群组分配记录")
    }

    // MARK: - PM.PrivilegeTAnyResource

    func test_PrivilegeTAnyResource() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let suffix = UUID().uuidString

        // 创建临时 privilege 和 resource
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "PivotTest-AnyRes-Priv-\(suffix)",
                description: "Pivot DTO 测试专用",
                policy: "allow if { true }"
            )
        ])
        let privilegeDTO = try #require(privileges.first)
        let resource = JsonResource(name: "PivotTest-AnyRes-\(suffix)", content: [:])
        let resourceDTO = try await m.resource.create(resources: [resource]).first!
        let anyResourceDTO = try #require(AnyResource(resourceDTO))

        defer {
            Task {
                try? await m.privilege.delete(policy: privilegeDTO)
                try? await m.resource.delete(ids: [resourceDTO.id])
            }
        }

        // 绑定前：pivot 不应存在
        let beforeCount = try await m.query(PM<ResourceList>.PrivilegeTAnyResource.self)
            .filter(\.privilegeId == privilegeDTO.id)
            .count()
        #expect(beforeCount == 0, "绑定前 PrivilegeTAnyResource 应不存在")

        // Attach
        try await m.privilege.attach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }

        // 1. 通过 privilegeId 过滤
        let byPrivilege = try await m.query(PM<ResourceList>.PrivilegeTAnyResource.self)
            .filter(\.privilegeId == privilegeDTO.id)
            .all()
        #expect(byPrivilege.count == 1, "Attach 后应有且仅有 1 条记录")

        // 2. 通过 resourceId 过滤
        let byResource = try await m.query(PM<ResourceList>.PrivilegeTAnyResource.self)
            .filter(\.resourceId == anyResourceDTO.id)
            .all()
        #expect(!byResource.isEmpty, "通过 resourceId 应能检索到 pivot")
        #expect(byResource.contains { $0.privilegeId == privilegeDTO.id })

        // 3. 字段映射正确性
        let pivot = try #require(byPrivilege.first)
        #expect(pivot.primaryId == pivot.privilegeId,  "primaryId 应等价于 privilegeId")
        #expect(pivot.secondaryId == pivot.resourceId,  "secondaryId 应等价于 resourceId")
        #expect(pivot.privilegeId == privilegeDTO.id)
        #expect(pivot.resourceId == anyResourceDTO.id)

        // 4. is(privilege:attachedTo:) 高层 API 与 Pivot 一致
        let attached = try await m.privilege.is(privilege: privilegeDTO, attachedTo: anyResourceDTO)
        #expect(attached == true, "is(privilege:attachedTo:) 应返回 true")

        // Detach
        try await m.privilege.detach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }

        // 解绑后 pivot 应消失
        let afterCount = try await m.query(PM<ResourceList>.PrivilegeTAnyResource.self)
            .filter(\.privilegeId == privilegeDTO.id)
            .count()
        #expect(afterCount == 0, "Detach 后 PrivilegeTAnyResource 应消失")

        // 高层 API 亦应反映解绑结果
        let attachedAfter = try await m.privilege.is(privilege: privilegeDTO, attachedTo: anyResourceDTO)
        #expect(attachedAfter == false, "Detach 后 is(privilege:attachedTo:) 应返回 false")
    }

    // MARK: - PM.PrivilegeTResource<G>（具体泛型资源）

    func test_PrivilegeTResource() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let suffix = UUID().uuidString

        // 使用具体类型 FileResource 测试 PrivilegeTResource<FileResource>
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "PivotTest-TypedRes-Priv-\(suffix)",
                description: "Pivot DTO 具体类型测试专用",
                policy: "allow if { true }"
            )
        ])
        let privilegeDTO = try #require(privileges.first)

        let file = FileResource(
            name: "PivotTest-File-\(suffix)",
            path: "/tmp/pivot_test_\(suffix).txt",
            isPrivate: false
        )
        let fileResources: [QFileResource] = try await m.resource.create(resources: [file])
        let fileResourceDTO = try #require(fileResources.first)
        let anyResourceDTO  = try #require(AnyResource(fileResourceDTO))

        defer {
            Task {
                try? await m.privilege.delete(policy: privilegeDTO)
                try? await m.resource.delete(ids: [fileResourceDTO.id])
            }
        }

        // Attach
        try await m.privilege.attach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }

        // 1. 通过 PrivilegeTResource<FileResource> query
        let typed = try await m.query(PM<ResourceList>.PrivilegeTResource<FileResource>.self)
            .filter(\.privilegeId == privilegeDTO.id)
            .all()
        #expect(typed.count == 1, "PrivilegeTResource<FileResource> 应查到 1 条记录")

        // 2. 通过 resourceId 过滤
        let byRes = try await m.query(PM<ResourceList>.PrivilegeTResource<FileResource>.self)
            .filter(\.resourceId == fileResourceDTO.id)
            .all()
        #expect(!byRes.isEmpty)
        #expect(byRes.contains { $0.privilegeId == privilegeDTO.id })

        // 3. 字段映射正确性
        let pivot = try #require(typed.first)
        #expect(pivot.primaryId == pivot.privilegeId,  "primaryId 应等价于 privilegeId")
        #expect(pivot.secondaryId == pivot.resourceId,  "secondaryId 应等价于 resourceId")
        #expect(pivot.privilegeId == privilegeDTO.id)
        #expect(pivot.resourceId == fileResourceDTO.id)

        // 4. privilege(attachedTo:) 高层 API
        let attached = try await m.privilege.privilege(attachedTo: fileResourceDTO)
        #expect(attached.contains { $0.id == privilegeDTO.id },
                "privilege(attachedTo: TypedResource) 应返回已绑定的 privilege")

        // 5. is(privilege:attachedTo:) typed API
        let isAttached = try await m.privilege.is(privilege: privilegeDTO, attachedTo: fileResourceDTO)
        #expect(isAttached == true)

        // Detach
        try await m.privilege.detach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }

        // 解绑后
        let afterTyped = try await m.query(PM<ResourceList>.PrivilegeTResource<FileResource>.self)
            .filter(\.privilegeId == privilegeDTO.id)
            .count()
        #expect(afterTyped == 0, "Detach 后 PrivilegeTResource 应消失")

        let isAttachedAfter = try await m.privilege.is(privilege: privilegeDTO, attachedTo: fileResourceDTO)
        #expect(isAttachedAfter == false)
    }
}
