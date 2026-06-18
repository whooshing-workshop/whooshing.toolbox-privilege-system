import Testing
import Foundation
import Query
import Fluent
import ErrorHandle
import Policy
import OrderedCollections
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import DTOBuilder

typealias GT = GroupTesting

@Suite("群组 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct GroupTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .group {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var ids: OrderedSet<UUID> = []
    
    static let groups: OrderedSet<PGroup> = [
        .init(under: nil, name: "AdministratorGroup", description: "全系统管理员的集合群组，拥有最高系统访问权限"),
        .init(under: nil, name: "OperatorGroup", description: "运营管理群组"),
        .init(under: nil, name: "DeveloperHub", description: "后端服务器与前端客户端的研发群体"),
        .init(under: nil, name: "BannedUsers", description: "被封禁和限制访问的用户集合"),
        .init(under: nil, name: "StandardUsers", description: "普通注册用户群体"),
        .init(under: nil, name: "GuestUsers", description: "游客群体"),
        .init(under: nil, name: "SalesTeam", description: "销售团队"),
        .init(under: nil, name: "MarketingTeam", description: "市场营销"),
        .init(under: nil, name: "HumanResources", description: "人力资源"),
        .init(under: nil, name: "QualityAssurance", description: "质量保障"),
        .init(under: nil, name: "Designers", description: "UI/UX 设计"),
        .init(under: nil, name: "DataAnalysts", description: "数据分析师"),
        .init(under: nil, name: "CustomerSupport", description: "客户支持"),
        .init(under: nil, name: "LegalDepartment", description: "法务部"),
        .init(under: nil, name: "FinanceDepartment", description: "财务部"),
        .init(under: nil, name: "Contractors", description: "外包人员")
    ]
    
    static var updates: [(PGroup.Updater, String, @Sendable (QGroup) -> Bool)] {[
        (
            .init(groupId: Self.ids[1]).update(description: "核心运营群组"),
            "修改群组1的描述",
            { $0.description! == "核心运营群组" }
        ),
        (
            .init(groupId: Self.ids[2]).update(name: "NinjaDevelopers").update(description: "神出鬼没的开发者"),
            "修改群组2的名字与描述",
            { $0.name == "NinjaDevelopers" && $0.description! == "神出鬼没的开发者" }
        )
    ]}
    
    @Test("创建群组")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        _ = try await s.group.create(groups: Self.groups)
    }
    
    @Test("查询并组装群组数据")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await s.query(QGroup.self).count() == Self.groups.count)
        
        let res = try await s.query(QGroup.self)
            .group(.or) { g in
                g.filter(\.name == "OperatorGroup")
                 .filter(\.name == "StandardUsers")
            }
            .all()
            
        
        #expect(res.count == 2)
        
        Self.ids = []
        for groupParam in Self.groups {
            let u = try #require(
                try await s.query(QGroup.self)
                    .filter(\.name == groupParam.name)
                    .first()
                    
            )
            Self.ids.append(u.id)
        }
        
        #expect(Self.ids.count == Self.groups.count)
    }
    
    @Test("群组更新测试")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (updater, msg, verifier) in Self.updates {
            let res = try await s.group.update(with: updater)
            #expect(verifier(res), "验证失败: \(msg)")
        }
    }
    
    @Test("群组关联与移除测试")
    func relationAndKick() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all()
        let groups = try await s.query(QGroup.self).all()
        
        let user = users[0]
        let group = groups[0]
        
        // join
        try await s.group.join { OrderedSet([user]) => OrderedSet([group]) }
        let count1 = try await __SDBM.UserGroupPivot.query(on: s.db).count()
        #expect(count1 == 1)
        
        // query(relations:) 验证
        let relations = try await s.group.query(relations: [.init(userId: user.id, groupId: group.id)])
        #expect(relations.count == 1)
        #expect(relations[0].userId == user.id)
        #expect(relations[0].groupId == group.id)
        
        // kick 后验证清理
        try await s.group.kick { OrderedSet([user]) => OrderedSet([group]) }
        let count2 = try await __SDBM.UserGroupPivot.query(on: s.db).count()
        #expect(count2 == 0)
    }
    
    // =========================================================================
    // MARK: group_paths 内接表核心验证
    // =========================================================================
    // 设计：create() 自动写入自循环路径（ancestor==descendant，depth==0）
    //        move()  原子化地断旧链、接新链、更新主表 parent_id
    // 验证策略：统一用 __SDBM.Group.Path 查询，不再用 __SDBM.Group 的 parentId 字段
    // =========================================================================

    // -------------------------------------------------------------------------
    // MARK: 1. create 后自循环路径验证
    // -------------------------------------------------------------------------

    @Test("group_paths：create 后每个群组应有且仅有 1 条 depth=0 的自循环路径")
    func paths_SelfLoopAfterCreate() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // 所有群组创建后，group_paths 中应有 groups.count 条自循环路径
        let totalPaths = try await __SDBM.Group.Path.query(on: s.db).count()
        #expect(totalPaths == Self.groups.count,
                "创建 \(Self.groups.count) 个群组后 group_paths 应有等量自循环路径")

        // 验证每条自循环路径均 depth=0 且 ancestor==descendant
        let selfLoops = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$depth == 0)
            .all()
        #expect(selfLoops.count == Self.groups.count, "所有路径应均为 depth=0 自循环")
        for loop in selfLoops {
            #expect(loop.$ancestor.id == loop.$descendant.id,
                    "depth=0 路径的 ancestor_id 与 descendant_id 应相同")
        }

        // 验证特定群组的自循环路径存在
        let adminSelf = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .filter(\.$descendant.$id == GT.ids[0])
            .first()
        #expect(adminSelf != nil, "AdministratorGroup 应有自循环路径")
        #expect(adminSelf?.depth == 0)
    }

    // -------------------------------------------------------------------------
    // MARK: 2. move 单层：GT.ids[6] → GT.ids[0]（SalesTeam 进 AdministratorGroup）
    // -------------------------------------------------------------------------

    @Test("move 单层：GT.ids[6] 移入 GT.ids[0]，group_paths 应增加直接子路径")
    func paths_MoveSingleLevel_Child6ToParent0() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allGroups = try await s.query(QGroup.self).all()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[0] }))  // AdministratorGroup
        let child  = try #require(allGroups.first(where: { $0.id == GT.ids[6] }))  // SalesTeam

        let pathsBefore = try await __SDBM.Group.Path.query(on: s.db).count()

        // move: child => parent（可选类型）
        try await s.group.move(child.id => parent.id)

        // group_paths 应新增 1 条路径（parent.ancestor → child.descendant，depth=1）
        let pathsAfter = try await __SDBM.Group.Path.query(on: s.db).count()
        #expect(pathsAfter == pathsBefore + 1, "move 单层后 group_paths 应增加 1 条路径")

        // 验证具体路径：ancestor=GT.ids[0], descendant=GT.ids[6], depth=1
        let direct = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .filter(\.$descendant.$id == GT.ids[6])
            .first()
        #expect(direct != nil, "应存在 AdministratorGroup → SalesTeam 的路径")
        #expect(direct?.depth == 1, "直接父子关系 depth 应为 1")
    }

    @Test("move 单层：GT.ids[7] 移入 GT.ids[0]，group_paths 正确新增")
    func paths_MoveSingleLevel_Child7ToParent0() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allGroups = try await s.query(QGroup.self).all()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[0] }))
        let child  = try #require(allGroups.first(where: { $0.id == GT.ids[7] }))  // MarketingTeam

        try await s.group.move(child.id => parent.id)

        let direct = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .filter(\.$descendant.$id == GT.ids[7])
            .first()
        #expect(direct != nil, "应存在 AdministratorGroup → MarketingTeam 的路径")
        #expect(direct?.depth == 1)
    }

    @Test("move 单层：GT.ids[8] 移入 GT.ids[1]，group_paths 正确新增")
    func paths_MoveSingleLevel_Child8ToParent1() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allGroups = try await s.query(QGroup.self).all()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[1] }))  // OperatorGroup
        let child  = try #require(allGroups.first(where: { $0.id == GT.ids[8] }))  // HumanResources

        try await s.group.move(child.id => parent.id)

        let direct = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[1])
            .filter(\.$descendant.$id == GT.ids[8])
            .first()
        #expect(direct != nil)
        #expect(direct?.depth == 1)
    }

    // -------------------------------------------------------------------------
    // MARK: 3. 验证单层移动后的 group_paths 全貌
    // -------------------------------------------------------------------------

    @Test("group_paths 全貌：单层 move 后 GT.ids[0] 应有 3 条路径（含自循环）")
    func paths_QueryAllPathsUnderParent0() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // 此时 GT.ids[0] 已经是 GT.ids[6] 和 GT.ids[7] 的 parent
        // group_paths 中以 GT.ids[0] 为 ancestor 的路径：
        //   [0→0 depth=0], [0→6 depth=1], [0→7 depth=1] → 3 条
        let pathsFromAdmin = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .all()
        #expect(pathsFromAdmin.count == 3,
                "AdministratorGroup 为起点的路径应有 3 条（自循环+2个子）")

        // GT.ids[1] 的路径：[1→1 depth=0], [1→8 depth=1] → 2 条
        let pathsFromOp = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[1])
            .all()
        #expect(pathsFromOp.count == 2, "OperatorGroup 为起点的路径应有 2 条")

        // 孤立群组 GT.ids[3]（BannedUsers）应只有自循环
        let pathsBanned = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[3])
            .all()
        #expect(pathsBanned.count == 1, "BannedUsers 应只有自循环路径")
        #expect(pathsBanned[0].depth == 0)
    }

    // -------------------------------------------------------------------------
    // MARK: 4. move 多层：GT.ids[9] → GT.ids[6]（三层嵌套 0→6→9）
    // -------------------------------------------------------------------------

    @Test("move 多层：GT.ids[9] 移入 GT.ids[6]，形成三层链 GT.ids[0→6→9]")
    func paths_MoveMultiLevel_Child9ToChild6() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // 前置：GT.ids[6](SalesTeam) 已在 GT.ids[0](AdministratorGroup) 下
        let allGroups = try await s.query(QGroup.self).all()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[6] }))  // SalesTeam
        let child  = try #require(allGroups.first(where: { $0.id == GT.ids[9] }))  // QualityAssurance

        try await s.group.move(child.id => parent.id)

        // group_paths 应出现：
        //   0 → 9 depth=2（AdministratorGroup 到 QualityAssurance）
        //   6 → 9 depth=1（SalesTeam 到 QualityAssurance）
        //   9 → 9 depth=0（自循环）
        let path_0_9 = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .filter(\.$descendant.$id == GT.ids[9])
            .first()
        #expect(path_0_9 != nil, "应存在 AdministratorGroup → QualityAssurance 的跨层路径")
        #expect(path_0_9?.depth == 2, "跨层路径 depth 应为 2")

        let path_6_9 = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[6])
            .filter(\.$descendant.$id == GT.ids[9])
            .first()
        #expect(path_6_9 != nil)
        #expect(path_6_9?.depth == 1)

        // GT.ids[0] 为 ancestor 的总路径应为：0→0, 0→6, 0→7, 0→9 → 4 条
        let pathsFromAdmin = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .all()
        #expect(pathsFromAdmin.count == 4,
                "三层结构下 AdministratorGroup 为起点的路径应有 4 条")
    }

    // -------------------------------------------------------------------------
    // MARK: 5. move 到根（脱离父群组，paths 旧链清除）
    // -------------------------------------------------------------------------

    @Test("move 到根：GT.ids[9] 脱离 GT.ids[6]，三层链被清除")
    func paths_MoveToRoot_Child9FromChild6() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // 前置：GT.ids[9] 在 GT.ids[6] 下（三层链 0→6→9）
        let freshGroups = try await s.query(QGroup.self).all()
        let child = try #require(freshGroups.first(where: { $0.id == GT.ids[9] }))

        // move 到 nil 表示脱离父群组，成为根节点
        try await s.group.move(child => QGroup?.none)

        // 旧链应被清除：不应再有 0→9 或 6→9 的路径
        let path_0_9 = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .filter(\.$descendant.$id == GT.ids[9])
            .first()
        #expect(path_0_9 == nil, "脱离后 AdministratorGroup → QualityAssurance 路径应被清除")

        let path_6_9 = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[6])
            .filter(\.$descendant.$id == GT.ids[9])
            .first()
        #expect(path_6_9 == nil, "脱离后 SalesTeam → QualityAssurance 路径应被清除")

        // GT.ids[9] 应只剩自循环
        let selfLoop = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[9])
            .all()
        #expect(selfLoop.count == 1, "脱离后 QualityAssurance 应只剩自循环路径")
        #expect(selfLoop[0].depth == 0)

        // GT.ids[0] 的路径恢复为 3 条（0→0, 0→6, 0→7）
        let pathsFromAdmin = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .all()
        #expect(pathsFromAdmin.count == 3,
                "脱离后 AdministratorGroup 路径应恢复为 3 条")
    }

    // -------------------------------------------------------------------------
    // MARK: 6. move 到根后再换 parent（路径完整重建）
    // -------------------------------------------------------------------------

    @Test("move 重建：GT.ids[9] 从根移入 GT.ids[1]，新链正确建立")
    func paths_MoveRebuild_Child9ToParent1() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // 前置：GT.ids[9] 已是根节点
        let freshGroups = try await s.query(QGroup.self).all()
        let newParent = try #require(freshGroups.first(where: { $0.id == GT.ids[1] }))  // OperatorGroup
        let child     = try #require(freshGroups.first(where: { $0.id == GT.ids[9] }))  // QualityAssurance

        try await s.group.move(child => Optional(newParent))

        // 新链：1→9 depth=1
        let path_1_9 = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[1])
            .filter(\.$descendant.$id == GT.ids[9])
            .first()
        #expect(path_1_9 != nil, "QualityAssurance 移入 OperatorGroup 后应有路径")
        #expect(path_1_9?.depth == 1)

        // 旧链不应存在（0→9 在前一步已被清除，不应重现）
        let path_0_9 = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .filter(\.$descendant.$id == GT.ids[9])
            .first()
        #expect(path_0_9 == nil, "不应有 AdministratorGroup → QualityAssurance 的旧链")

        // 清理：将 GT.ids[9] 脱离，保持后续测试环境干净
        let cleanGroups = try await s.query(QGroup.self).all()
        let cleanChild = try #require(cleanGroups.first(where: { $0.id == GT.ids[9] }))
        try await s.group.move(cleanChild => QGroup?.none)
    }

    // -------------------------------------------------------------------------
    // MARK: 7. move 非法：将父群组移入其子孙（循环检测）
    // -------------------------------------------------------------------------

    @Test("move 非法：将父群组 GT.ids[0] 移入其子群组 GT.ids[6]，应抛出 groupMoveFailed")
    func paths_MoveIllegal_ParentIntoChild() async throws {
        let (s, _) = try await TestingShared.getSystem()
        // 前置：GT.ids[6] 在 GT.ids[0] 下，即 GT.ids[0] 是 GT.ids[6] 的祖先
        let freshGroups = try await s.query(QGroup.self).all()
        let parent = try #require(freshGroups.first(where: { $0.id == GT.ids[0] }))
        let child  = try #require(freshGroups.first(where: { $0.id == GT.ids[6] }))

        // 尝试把 AdministratorGroup 移入其子 SalesTeam → 应报错
        var didThrow = false
        do {
            try await s.group.move(parent.id => child.id)
        } catch {
            // 任何错误都意味着 move 被正确拦截
            didThrow = true
        }
        #expect(didThrow, "将父群组移入子群组应抛出错误，不应成功执行")

        // group_paths 不应发生改变，AdministratorGroup 路径条数保持 3 条
        let pathsFromAdmin = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[0])
            .all()
        #expect(pathsFromAdmin.count == 3, "非法 move 后 paths 不应改变")
    }

    @Test("move 非法：将群组移入自身，应抛出 groupMoveFailed")
    func paths_MoveIllegal_SelfToSelf() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let allGroups = try await s.query(QGroup.self).all()
        let group = try #require(allGroups.first(where: { $0.id == GT.ids[3] }))  // BannedUsers（独立群组）

        var didThrow = false
        do {
            try await s.group.move(group.id => group.id)
        } catch {
            didThrow = true
        }
        #expect(didThrow, "将群组移入自身应抛出错误")
    }

    // -------------------------------------------------------------------------
    // MARK: 8. 删除父群组后子孙连坐（group_paths 级联清理验证）
    // -------------------------------------------------------------------------

    @Test("delete 级联：临时父子树删除后 group_paths 完整清除")
    func paths_DeleteCascade_Parent0() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // 临时创建一个小树：tempParent → tempChild1, tempChild2
        // 用于验证删除父节点时子孙及所有 group_paths 一并清除
        let created = try await s.group.create(groups: [
            .init(under: nil, name: "TempParent",  description: "临时父群组"),
            .init(under: nil, name: "TempChild1",  description: "临时子群组1"),
            .init(under: nil, name: "TempChild2",  description: "临时子群组2"),
        ])
        let allGroups = try await s.query(QGroup.self).all()
        let tempParent = try #require(allGroups.first(where: { $0.name == "TempParent" }))
        let tempChild1 = try #require(allGroups.first(where: { $0.name == "TempChild1" }))
        let tempChild2 = try #require(allGroups.first(where: { $0.name == "TempChild2" }))

        // 建立层级：tempChild1, tempChild2 → tempParent
        try await s.group.move(tempChild1.id => tempParent.id)
        try await s.group.move(tempChild2.id => tempParent.id)

        // 此时 group_paths 中应有：
        //   TempParent→TempParent (0), TempParent→TempChild1 (1), TempParent→TempChild2 (1)
        //   TempChild1→TempChild1 (0), TempChild2→TempChild2 (0)
        // 共 5 条新路径
        let pathsBefore = try await __SDBM.Group.Path.query(on: s.db).count()

        let tempParentId = try #require(created.first(where: { $0.name == "TempParent" })?.id)

        // 删除父节点，应级联删除 TempChild1, TempChild2 及所有路径
        try await s.group.delete(groupIds: [tempParentId])

        // 主表：三个临时群组应全部消失
        for name in ["TempParent", "TempChild1", "TempChild2"] {
            let found = try await s.query(QGroup.self)
                .filter(\.name == name).first()
            #expect(found == nil, "\(name) 被级联删除后不应存在")
        }

        // group_paths：3 个群组的 5 条路径应全部清除
        let pathsAfter = try await __SDBM.Group.Path.query(on: s.db).count()
        #expect(pathsAfter == pathsBefore - 5,
                "删除临时父子树（3个群组）后 group_paths 应减少 5 条")

        // GT.ids[1]（OperatorGroup）及 GT.ids[8] 的路径不应受影响
        let pathsFromOp = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == GT.ids[1])
            .all()
        #expect(pathsFromOp.count == 2, "OperatorGroup 的路径不应受临时树删除影响")
    }

    @Test("群组删除测试：孤立叶子群组的单独删除")
    func delete() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // 临时创建一个孤立群组（无父无子），用于独立删除测试
        let temp = try await s.group.create(groups: [
            .init(under: nil, name: "TempDeleteGroup", description: "临时删除测试群组")
        ])
        let tempId = try #require(temp.first?.id)

        // 创建后应有自循环路径
        let pathAfterCreate = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == tempId)
            .all()
        #expect(pathAfterCreate.count == 1, "孤立群组创建后应有 1 条自循环路径")

        let countBefore = try await s.query(QGroup.self).count()

        try await s.group.delete(groupIds: [tempId])

        // 主表中不应再找到该群组
        let found = try await s.query(QGroup.self)
            .filter(\.name == "TempDeleteGroup")
            .first()
        #expect(found == nil, "被删除的群组不应被查询到")

        let countAfter = try await s.query(QGroup.self).count()
        #expect(countAfter == countBefore - 1, "删除后群组数量应减少 1")

        // group_paths 中该群组的自循环路径也应被清除
        let pathAfterDelete = try await __SDBM.Group.Path.query(on: s.db)
            .filter(\.$ancestor.$id == tempId)
            .first()
        #expect(pathAfterDelete == nil, "群组删除后 group_paths 中的自循环路径应一并清除")
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
