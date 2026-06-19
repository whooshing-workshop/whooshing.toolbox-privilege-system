import Vapor
import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import Query
@testable import DTOBuilder

@Suite("PropertyWrapper 关系测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct PropertyWrapperTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .propertyWrapper {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("OptionalSub 属性包装器测试")
    func testOptionalSub() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 查找一个有 user info 的 user (例如 AT.ids[0])
        let user = try await s.query(QUser.self)
            .filter(\.id == AT.ids[0])
            .first()
        
        let u = try #require(user)
        
        // 验证未加载时的状态
        #expect(u.$info.loaded == false)
        
        // 加载 info
        try await u.$info.load(on: s).get()
        
        #expect(u.$info.loaded == true)
        #expect(u.info != nil)
        #expect(u.info?.nickname == "HelloWorld")
    }
    
    @Test("Sub 属性包装器测试")
    func testSub() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 手动实例化 SubProperty 来测试，因为现有 DTO 里暂无直接使用 @Sub 的字段 (它们大多用 @OptionalSub)
        let subProperty = SubProperty<QUser, QUserInfo>(for: \QUserInfo.$user)
        subProperty.fromId = AT.ids[0]
        
        #expect(subProperty.loaded == false)
        
        try await subProperty.load(on: s).get()
        
        #expect(subProperty.loaded == true)
        #expect(subProperty.wrappedValue.nickname == "HelloWorld")
    }
    
    @Test("OptionalSuper 属性包装器测试")
    func testOptionalSuper() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 找到有父群组的群组 (由 GT.ids[0] 和 GT.ids[6] 构成父子关系，即 parentId 为 GT.ids[0])
        let group = try await s.query(QGroup.self)
            .filter(\.id == GT.ids[6])
            .first()
            
        let g = try #require(group)
        
        #expect(g.$parent.loaded == false)
        
        try await g.$parent.load(on: s).get()
        
        #expect(g.$parent.loaded == true)
        #expect(g.parent != nil)
        #expect(g.parent?.id == GT.ids[0])
    }
    
    @Test("Super 属性包装器测试")
    func testSuper() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // QUserInfo.user 是 @Super 关系
        let userInfo = try await s.query(QUserInfo.self)
            .filter(\.$user.id == AT.ids[0])
            .first()
            
        let info = try #require(userInfo)
        
        #expect(info.$user.loaded == false)
        
        try await info.$user.load(on: s).get()
        
        #expect(info.$user.loaded == true)
        #expect(info.user.id == AT.ids[0])
    }
    
    @Test("Subs 属性包装器测试")
    func testSubs() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // QGroup.childs 是 @Subs 关系
        let group = try await s.query(QGroup.self)
            .filter(\.id == GT.ids[0])
            .first()
            
        let g = try #require(group)
        
        #expect(g.$childs.loaded == false)
        
        try await g.$childs.load(on: s).get()
        
        #expect(g.$childs.loaded == true)
        #expect(g.childs.count > 0)
        #expect(g.childs.contains { $0.id == GT.ids[6] })
    }
    
    @Test("Sibling 属性包装器测试")
    func testSibling() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // QUser.groups 是 @Sibling 关系
        let user = try await s.query(QUser.self)
            .filter(\.id == AT.ids[0])
            .first()
            
        let u = try #require(user)
        
        #expect(u.$groups.loaded == false)
        #expect(u.$groups.idsLoaded == false)
        
        // 只加载 IDs
        try await u.$groups.loadIdsOnly(on: s).get()
        #expect(u.$groups.idsLoaded == true)
        #expect(u.$groups.loaded == false)
        #expect(u.$groups.ids.contains(GT.ids[0]))
        
        // 完整加载
        try await u.$groups.load(on: s).get()
        #expect(u.$groups.loaded == true)
        #expect(u.groups.contains { $0.id == GT.ids[0] })
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
