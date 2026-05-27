import Vapor
import Testing
import AnyCodable
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import ResourceMacros
@testable import Policy

enum MockOperation: String, OperationList {
    case read
}

struct MockResource: Resource, Hashable {
    typealias ResourceType = ResourceList
    typealias Operations = MockOperation
    
    static let type: ResourceList = .file
    let name: String
    
    var id: String { name }
    var json: [String : AnyCodable] { ["name": AnyCodable(name)] }
    
    static var mirrors: [PartialKeyPath<MockResource>: [String]] {
        [\.name: ["name"]]
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
        
        let p1 = PUser(email: email, hashedPasswd: passwd)
        let p2 = PUser(email: email, hashedPasswd: passwd)
        let p3 = PUser(email: "other@example.com", hashedPasswd: passwd)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PUser>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let userModel = User()
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
        
        let p1 = PDomain(name: name, description: desc)
        let p2 = PDomain(name: name, description: desc)
        let p3 = PDomain(name: "OtherDomain", description: desc)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PDomain>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = Domain()
        model.name = name
        model.description = desc
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
        
        let p1 = PGroup(under: nil, name: name, description: desc)
        let p2 = PGroup(under: nil, name: name, description: desc)
        let p3 = PGroup(under: nil, name: "OtherGroup", description: desc)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PGroup>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = UGroup()
        model.name = name
        model.description = desc
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
        
        let p1 = PRole(name: name, description: desc)
        let p2 = PRole(name: name, description: desc)
        let p3 = PRole(name: "OtherRole", description: desc)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
        
        var set = Set<PRole>()
        set.insert(p1)
        #expect(set.contains(p2))
        
        let model = Role()
        model.name = name
        model.description = desc
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
        
        let model = PolicyExp<Role>()
        model.moduleId = moduleId
        model.policy = policyStr
        model.id = UUID()
        
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
        
        let model = UserModel.Info()
        model.nickname = nickname
        model.identifier = identifier
        model.birthday = birthday
        model.id = UUID()
        model.other = nil
        model.$user.id = UUID()
        
        let q1 = try QUserInfo.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("UserInGroupRelationDTO Hashable & Equatable")
    func testUserInGroupRelationDTO() async throws {
        let umodel = User()
        umodel.email = "test@example.com"
        umodel.id = UUID()
        umodel.hashedPasswd = "XXX"
        umodel.key = Data()
        umodel.salt = Data()
        umodel.createdAt = Date()
        umodel.updatedAt = Date()
        let quser = try QUser.make(from: umodel).get()
        
        let gmodel = UGroup()
        gmodel.name = "TestGroup"
        gmodel.id = UUID()
        gmodel.description = nil
        gmodel.createdAt = Date()
        gmodel.updatedAt = Date()
        let qgroup = try QGroup.make(from: gmodel).get()
        
        let p1 = PUserInGroupRelation(user: quser, group: qgroup)
        let p2 = PUserInGroupRelation(user: quser, group: qgroup)
        
        #expect(p1 == p2)
        
        let model = UserGroupPivot()
        model.$user.value = umodel
        model.$group.value = gmodel
        model.id = UUID()
        
        let q1 = try QUserInGroupRelation.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("TokenDTO Hashable & Equatable")
    func testTokenDTO() async throws {
        let cred = "TestCred"
        
        let p1 = PToken(credential: cred, tokenEncrypted: Data())
        let p2 = PToken(credential: cred, tokenEncrypted: Data())
        
        #expect(p1 == p2)
        
        let model = Token()
        model.credential = cred
        model.id = UUID()
        model.$user.id = UUID()
        model.token = "TestToken"
        model.valid = true
        model.expireAfter = 7 * 24 * 60
        model.createdAt = Date()
        
        let q1 = try QToken.make(from: model).get()
        
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
        
        let model = User.Info.Extended<UserInfoExtends.Address>()
        model.value = value
        model.order = order
        model.id = UUID()
        model.description = nil
        model.$userInfo.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try QAddressSlice.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("ExtendedInfoDTO Hashable & Equatable")
    func testExtendedInfoDTO() async throws {
        let value = "TestValue"
        let order: Int16 = 1
        
        let pSlice = PAddressSlice(value: value, order: order)
        
        let model = User.Info.Extended<UserInfoExtends.Address>()
        model.value = value
        model.order = order
        model.id = UUID()
        model.description = nil
        model.$userInfo.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let qSlice = try QAddressSlice.make(from: model).get()
        
        let p1 = PExtendedInfo(addresses: [pSlice])
        let q1 = QExtendedInfo(addresses: [qSlice])
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("PrivilegeDTO Hashable & Equatable")
    func testPrivilegeDTO() async throws {
        let name = "TestPriv"
        let policy = "allow"
        let date = Date()
        
        // PrivilegeDTO init requires internal initializers or public ones?
        // Let's use the internal one since we use @testable!
        var p1 = PM<ResourceList>.PrivilegeDTO<DTO.Prepare>(_name: name, _description: nil, _policy: policy, _model: nil)
        var p2 = PM<ResourceList>.PrivilegeDTO<DTO.Prepare>(_name: name, _description: nil, _policy: policy, _model: nil)
        
        p1.createdAt = date
        p1.updatedAt = date
        p2.createdAt = date
        p2.updatedAt = date
        
        #expect(p1 == p2)
        
        let model = PM<ResourceList>.Privilege()
        model.name = name
        model.policy = policy
        model.description = nil
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try PM<ResourceList>.PrivilegeDTO<DTO.Queried>.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @Test("ResourceDTO Hashable & Equatable")
    func testResourceDTO() async throws {
        let res = MockResource(name: "TestRes")
        let date = Date()
        
        var p1 = PM<ResourceList>.ResourceDTO<MockResource, DTO.Prepare>(_data: res, _model: nil)
        var p2 = PM<ResourceList>.ResourceDTO<MockResource, DTO.Prepare>(_data: res, _model: nil)
        
        p1.createdAt = date
        p1.updatedAt = date
        p2.createdAt = date
        p2.updatedAt = date
        
        #expect(p1 == p2)
        
        let model = PM<ResourceList>.ResourceModel<MockResource>()
        model.data = res
        model.id = UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        
        let q1 = try PM<ResourceList>.ResourceDTO<MockResource, DTO.Queried>.make(from: model).get()
        
        #expect(p1.like(q1))
        #expect(q1.like(p1))
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .account
    }
}
