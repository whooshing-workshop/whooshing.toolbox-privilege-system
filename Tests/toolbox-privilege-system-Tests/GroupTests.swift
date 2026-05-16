import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
import Foundation
import Query
import Fluent

typealias GT = GroupTesting

@Suite("群组 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct GroupTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .group {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var ids: [UUID] = []
    
    static let groups: [PGroup] = [
        .init(name: "AdministratorGroup", description: "全系统管理员的集合群组，拥有最高系统访问权限"),
        .init(name: "OperatorGroup", description: "运营管理群组"),
        .init(name: "DeveloperHub", description: "后端服务器与前端客户端的研发群体"),
        .init(name: "BannedUsers", description: "被封禁和限制访问的用户集合"),
        .init(name: "StandardUsers", description: "普通注册用户群体"),
        .init(name: "GuestUsers", description: "游客群体"),
        .init(name: "SalesTeam", description: "销售团队"),
        .init(name: "MarketingTeam", description: "市场营销"),
        .init(name: "HumanResources", description: "人力资源"),
        .init(name: "QualityAssurance", description: "质量保障"),
        .init(name: "Designers", description: "UI/UX 设计"),
        .init(name: "DataAnalysts", description: "数据分析师"),
        .init(name: "CustomerSupport", description: "客户支持"),
        .init(name: "LegalDepartment", description: "法务部"),
        .init(name: "FinanceDepartment", description: "财务部"),
        .init(name: "Contractors", description: "外包人员")
    ]
    
    static var updates: [(PGroup.Updater, String, @Sendable (QGroup) -> Bool)] {[
        (
            .init(groupId: Self.ids[1]).update(description: "核心运营群组"),
            "修改群组1的描述",
            { $0.description == "核心运营群组" }
        ),
        (
            .init(groupId: Self.ids[2]).update(name: "NinjaDevelopers").update(description: "神出鬼没的开发者"),
            "修改群组2的名字与描述",
            { $0.name == "NinjaDevelopers" && $0.description == "神出鬼没的开发者" }
        )
    ]}
    
    @Test("创建群组")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        _ = try await s.group.create(groups: Self.groups).get()
    }
    
    @Test("查询并组装群组数据")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await s.query(QGroup.self).count().get() == Self.groups.count)
        
        let res = try await s.query(QGroup.self)
            .group(.or) { g in
                g.filter(\.name == "OperatorGroup")
                 .filter(\.name == "StandardUsers")
            }
            .all()
            .get()
        
        #expect(res.count == 2)
        
        Self.ids = []
        for groupParam in Self.groups {
            let u = try #require(
                try await s.query(QGroup.self)
                    .filter(\.name == groupParam.name)
                    .first()
                    .get()
            )
            Self.ids.append(u.id)
        }
        
        #expect(Self.ids.count == Self.groups.count)
    }
    
    @Test("群组更新测试")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (updater, msg, verifier) in Self.updates {
            let res = try await s.group.update(with: updater).get()
            #expect(verifier(res), "验证失败: \(msg)")
        }
    }
    
    @Test("群组关联与移除测试")
    func relationAndKick() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let users = try await s.query(QUser.self).all().get()
        let groups = try await s.query(QGroup.self).all().get()
        
        let user = users[0]
        let group = groups[0]
        
        // join
        try await s.group.join { [user] => [group] }.get()
        let count1 = try await UserGroupPivot.query(on: s.db).count().get()
        #expect(count1 == 1)
        
        // query(relations:) 验证
        let relations = try await s.group.query(relations: [user =| group]).get()
        #expect(relations.count == 1)
        #expect(relations[0].user.id == user.id)
        #expect(relations[0].group.id == group.id)
        
        // kick 后验证清理
        try await s.group.kick { [user] => [group] }.get()
        let count2 = try await UserGroupPivot.query(on: s.db).count().get()
        #expect(count2 == 0)
    }
    
    @Test("群组嵌套：embed 单父多子（GT.ids[0] 包含 GT.ids[6,7]）")
    func embedSingleParentMultipleChildren() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // 通过 GT.ids 精确取出父群组与子群组
        let allGroups = try await s.query(QGroup.self).all().get()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[0] }))  // AdministratorGroup
        let child6  = try #require(allGroups.first(where: { $0.id == GT.ids[6] }))  // SalesTeam
        let child7  = try #require(allGroups.first(where: { $0.id == GT.ids[7] }))  // MarketingTeam

        // 使用 builder DSL 将两个子群组嵌入父群组
        try await s.group.embed {
            [child6, child7] => parent
        }.get()

        // 验证 DB：GT.ids[6] 和 GT.ids[7] 的 parent_id 应指向 GT.ids[0]
        let updated6 = try #require(try await UGroup.find(GT.ids[6], on: s.db).get())
        let updated7 = try #require(try await UGroup.find(GT.ids[7], on: s.db).get())
        #expect(updated6.$parent.id == GT.ids[0], "SalesTeam 的 parent_id 应为 AdministratorGroup")
        #expect(updated7.$parent.id == GT.ids[0], "MarketingTeam 的 parent_id 应为 AdministratorGroup")
    }

    @Test("群组嵌套：embed 单父单子（GT.ids[1] 包含 GT.ids[8]）")
    func embedSingleParentSingleChild() async throws {
        let (s, _) = try await TestingShared.getSystem()

        let allGroups = try await s.query(QGroup.self).all().get()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[1] }))  // OperatorGroup
        let child  = try #require(allGroups.first(where: { $0.id == GT.ids[8] }))  // HumanResources

        try await s.group.embed {
            [child] => parent
        }.get()

        let updated = try #require(try await UGroup.find(GT.ids[8], on: s.db).get())
        #expect(updated.$parent.id == GT.ids[1], "HumanResources 的 parent_id 应为 OperatorGroup")
    }

    @Test("群组嵌套：embed 后 divorce 脱离父群组")
    func embedThenDivorce() async throws {
        let (s, _) = try await TestingShared.getSystem()

        let allGroups = try await s.query(QGroup.self).all().get()
        let parent = try #require(allGroups.first(where: { $0.id == GT.ids[2] }))  // DeveloperHub
        let child9  = try #require(allGroups.first(where: { $0.id == GT.ids[9] }))  // QualityAssurance
        let child10 = try #require(allGroups.first(where: { $0.id == GT.ids[10] })) // Designers

        // 先 embed
        try await s.group.embed {
            [child9, child10] => parent
        }.get()

        var q9  = try #require(try await UGroup.find(GT.ids[9], on: s.db).get())
        var q10 = try #require(try await UGroup.find(GT.ids[10], on: s.db).get())
        #expect(q9.$parent.id == GT.ids[2],  "embed 后 QualityAssurance.parent_id 应为 DeveloperHub")
        #expect(q10.$parent.id == GT.ids[2], "embed 后 Designers.parent_id 应为 DeveloperHub")

        // 再 divorce
        // divorce 需要已 embed 后的最新 QGroup DTO，先重新查询
        let freshGroups = try await s.query(QGroup.self).all().get()
        let freshChild9  = try #require(freshGroups.first(where: { $0.id == GT.ids[9] }))
        let freshChild10 = try #require(freshGroups.first(where: { $0.id == GT.ids[10] }))
        let freshParent  = try #require(freshGroups.first(where: { $0.id == GT.ids[2] }))

        try await s.group.divorce {
            [freshChild9, freshChild10] => freshParent
        }.get()

        q9  = try #require(try await UGroup.find(GT.ids[9], on: s.db).get())
        q10 = try #require(try await UGroup.find(GT.ids[10], on: s.db).get())
        #expect(q9.$parent.id == nil,  "divorce 后 QualityAssurance.parent_id 应为 nil")
        #expect(q10.$parent.id == nil, "divorce 后 Designers.parent_id 应为 nil")
    }

    @Test("群组嵌套：验证 GT.ids[0] 下有 2 个子群组，GT.ids[1] 下有 1 个")
    func queryChildGroups() async throws {
        let (s, _) = try await TestingShared.getSystem()

        // embed 已在前序测试中完成（GT.ids[0] → [6,7]，GT.ids[1] → [8]）
        let children0 = try await s.query(QGroup.self)
            .filter(\.parentId == GT.ids[0])
            .all().get()
        #expect(children0.count == 2, "AdministratorGroup 应有 2 个子群组")

        let children1 = try await s.query(QGroup.self)
            .filter(\.parentId == GT.ids[1])
            .all().get()
        #expect(children1.count == 1, "OperatorGroup 应有 1 个子群组")

        let childIds0 = children0.map { $0.id }
        #expect(childIds0.contains(GT.ids[6]), "SalesTeam 应在 AdministratorGroup 下")
        #expect(childIds0.contains(GT.ids[7]), "MarketingTeam 应在 AdministratorGroup 下")
    }

    @Test("群组删除测试")
    func delete() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 临时创建一个群组用于删除测试
        let temp = try await s.group.create(groups: [
            .init(name: "TempDeleteGroup", description: "临时删除测试群组")
        ]).get()
        
        let totalBefore = try await s.query(QGroup.self).count().get()
        #expect(totalBefore == Self.groups.count + 1)
        
        let tempId = try #require(temp.first?.id)
        try await s.group.delete(groupIds: [tempId]).get()
        
        let totalAfter = try await s.query(QGroup.self).count().get()
        #expect(totalAfter == Self.groups.count, "删除后群组数量应恢复")
        
        // 验证不存在
        let found = try await s.query(QGroup.self)
            .filter(\.name == "TempDeleteGroup")
            .first().get()
        #expect(found == nil, "被删除的群组不应被查询到")
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .role
    }
}
