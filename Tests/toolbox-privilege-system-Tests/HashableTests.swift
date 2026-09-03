import Testing
import Foundation
@testable import PrivilegeModule
@testable import PrivilegeSystem

enum MockOperation: String, OperationList {
    case read
}

struct MockResource: Resource, Hashable {
    typealias ResourceType = ResourceList
    typealias Operations = MockOperation
    
    static let type: ResourceList = .file
    let appId: String
    
    var id: String { appId }
    var json: [String : AnyCodable] { ["app_id": AnyCodable(appId)] }
    
    static var mirrors: [PartialKeyPath<MockResource>: [String]] {
        [\.appId: ["appId"]]
    }
}

@Suite("Hashable & Equatable 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct HashableTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .hashable {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("UserDTO Hashable & Equatable")
    func testUserDTO() async throws {
        let email = "test@example.com"
        let passwd = "password"
        
        let p1 = PUser(email: email, hashedPassword: passwd)
        let p2 = PUser(email: email, hashedPassword: passwd)
        let p3 = PUser(email: "other@example.com", hashedPassword: passwd)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PUser>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let userModel = __SDBM.User()
        userModel.email = email
        userModel.id = UUID()
        userModel.createdAt = Date()
        userModel.updatedAt = Date()
        
        let q1 = try QUser.make(from: userModel).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
        #expect(!p3.like(q1))
        
        #expect([p1].like([q1]))
        #expect([q1].like([p1]))
    }
    
    @Test("DomainDTO Hashable & Equatable")
    func testDomainDTO() async throws {
        let name = "TestDomain"
        let desc = "Test Description"
        
        let p1 = PDomain(name: name, summary: desc)
        let p2 = PDomain(name: name, summary: desc)
        let p3 = PDomain(name: "OtherDomain", summary: desc)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PDomain>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = __SDBM.Domain()
        model.name = name
        model.summary = desc
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QDomain.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
        #expect(!p3.like(q1))
    }
    
    @Test("GroupDTO Hashable & Equatable")
    func testGroupDTO() async throws {
        let name = "TestGroup"
        let desc = "Test Description"
        
        let p1 = PGroup(under: nil, name: name, summary: desc)
        let p2 = PGroup(under: nil, name: name, summary: desc)
        let p3 = PGroup(under: nil, name: "OtherGroup", summary: desc)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PGroup>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = __SDBM.Group()
        model.name = name
        model.summary = desc
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QGroup.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("RoleDTO Hashable & Equatable")
    func testRoleDTO() async throws {
        let name = "TestRole"
        let desc = "Test Description"
        
        let p1 = PRole(name: name, summary: desc)
        let p2 = PRole(name: name, summary: desc)
        let p3 = PRole(name: "OtherRole", summary: desc)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PRole>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = __SDBM.Role()
        model.name = name
        model.summary = desc
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QRole.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("PolicyDTO Hashable & Equatable")
    func testPolicyDTO() async throws {
        let moduleId = UUID()
        let policyStr = "allow if { true }"
        
        let p1 = PPolicy<Role>(moduleId: moduleId, policy: policyStr)
        let p2 = PPolicy<Role>(moduleId: moduleId, policy: policyStr)
        let p3 = PPolicy<Role>(moduleId: moduleId, policy: "allow if { false }")
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PPolicy<Role>>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = __SDBM.PolicyExp<Role>()
        model.moduleId = moduleId
        model.policy = policyStr
        model.$parent.id = UUID()
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QPolicy<Role>.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
        #expect(!p3.like(q1))
    }
    
    @Test("UserInfoDTO Hashable & Equatable")
    func testUserInfoDTO() async throws {
        let nickname = "TestNick"
        let identifier = "TestIdent"
        let birthday = Date()
        
        let p1 = PUserInfo(nickname: nickname, identifier: identifier, birthday: birthday, other: nil)
        let p2 = PUserInfo(nickname: nickname, identifier: identifier, birthday: birthday, other: nil)
        
        #expect(p1 == p2)
        
        let model = __SDBM.User.Info()
        model.nickname = nickname
        model.identifier = identifier
        model.birthday = birthday
        model.id = UUID()
        model.other = nil
        model.$user.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QUserInfo.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("UserInGroupRelationDTO Hashable & Equatable")
    func testUserInGroupRelationDTO() async throws {
        let umodel = __SDBM.User()
        umodel.email = "test@example.com"
        umodel.id = UUID()
        umodel.hashedPassword = "XXX"
        umodel.key = Data()
        umodel.salt = Data()
        umodel.createdAt = Date()
        umodel.updatedAt = Date()
        
        let gmodel = __SDBM.Group()
        gmodel.name = "TestGroup"
        gmodel.id = UUID()
        gmodel.summary = nil
        gmodel.createdAt = Date()
        gmodel.updatedAt = Date()
        let qgroup = try QGroup.make(from: gmodel).get()
        
        let p1 = PUserTGroup(userId: umodel.id!, groupId: qgroup.id)
        let p2 = PUserTGroup(userId: umodel.id!, groupId: qgroup.id)
        
        #expect(p1 == p2)
        
        let model = __SDBM.UserGroupPivot()
        model.$primaryModel.id = try umodel.requireID()
        model.$secondaryModel.id = try gmodel.requireID()
        model.id = UUID()
        model.createdAt = Date()
        
        let q1 = try UserTGroup.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("InfoSliceDTO Hashable & Equatable")
    func testInfoSliceDTO() async throws {
        let value = "TestValue"
        let order: Int16 = 1
        
        let p1 = PAddressSlice(value: value, order: order)
        let p2 = PAddressSlice(value: value, order: order)
        
        #expect(p1 == p2)
        
        let model = __SDBM.User.Info.Extended<UserInfoExtends.Address>()
        model.value = value
        model.order = order
        model.id = UUID()
        model.summary = nil
        model.$userInfo.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QAddressSlice.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("PrivilegeDTO Hashable & Equatable")
    func testPrivilegeDTO() async throws {
        let name = "TestPriv"
        let policy = "allow"
        
        // PrivilegeDTO init requires internal initializers or public ones?
        // Let's use the internal one since we use @testable!
        let p1 = PM<ResourceList>.PPrivilege(name: name, summary: nil, policy: policy)
        let p2 = PM<ResourceList>.PPrivilege(name: name, summary: nil, policy: policy)
        
        #expect(p1 == p2)
        
        let model = PM<ResourceList>.__DBM.Privilege()
        model.name = name
        model.policy = policy
        model.summary = nil
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try PM<ResourceList>.QPrivilege.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
