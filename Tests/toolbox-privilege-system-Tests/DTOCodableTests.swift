import Testing
import Foundation
@preconcurrency import AnyCodable
@testable import PrivilegeSystem

@Suite("DTO 序列化测试集", .serialized)
struct DTOCodableTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .dtoCodable {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("QToken 序列化和反序列化")
    func testTokenCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let token = try await s.query(QToken.self).first()
        guard let token = token else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 测试未加载情况下的序列化
        let data = try encoder.encode(token)
        let decoded = try decoder.decode(QToken.self, from: data)
        
        #expect(decoded.id == token.id)
        #expect(decoded.credential == token.credential)
        #expect(decoded.$user.loaded == false)
        #expect(decoded.$user.id == token.$user.id)
        
        // 测试已加载情况下的序列化
        try await token.$user.load(on: s).get()
        let dataLoaded = try encoder.encode(token)
        let decodedLoaded = try decoder.decode(QToken.self, from: dataLoaded)
        
        #expect(decodedLoaded.$user.loaded == true)
        #expect(decodedLoaded.$user.id == token.$user.id)
        #expect(decodedLoaded.$user.wrappedValue.id == token.$user.wrappedValue.id)
    }
    
    @Test("QRole 序列化和反序列化")
    func testRoleCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let role = try await s.query(QRole.self).first()
        guard let role = role else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 测试未加载状态
        let data = try encoder.encode(role)
        let decoded = try decoder.decode(QRole.self, from: data)
        
        #expect(decoded.id == role.id)
        #expect(decoded.name == role.name)
        #expect(decoded.$users.loaded == false)
        
        // 测试已加载状态
        try await role.$users.load(on: s).get()
        let dataLoaded = try encoder.encode(role)
        let decodedLoaded = try decoder.decode(QRole.self, from: dataLoaded)
        
        #expect(decodedLoaded.$users.loaded == true)
        #expect(decodedLoaded.$users.idsLoaded == true)
        #expect(decodedLoaded.$users.ids == role.$users.ids)
        #expect(decodedLoaded.$users.wrappedValue.count == role.$users.wrappedValue.count)
    }
    
    @Test("QDomain 序列化和反序列化")
    func testDomainCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let domain = try await s.query(QDomain.self).first()
        guard let domain = domain else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 测试未加载状态
        let data = try encoder.encode(domain)
        let decoded = try decoder.decode(QDomain.self, from: data)
        
        #expect(decoded.id == domain.id)
        #expect(decoded.name == domain.name)
        #expect(decoded.$users.loaded == false)
        
        // 测试已加载状态
        try await domain.$users.load(on: s).get()
        let dataLoaded = try encoder.encode(domain)
        let decodedLoaded = try decoder.decode(QDomain.self, from: dataLoaded)
        
        #expect(decodedLoaded.$users.loaded == true)
        #expect(decodedLoaded.$users.ids == domain.$users.ids)
    }
    
    @Test("QGroup 序列化和反序列化")
    func testGroupCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let group = try await s.query(QGroup.self).first()
        guard let group = group else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 测试未加载状态
        let data = try encoder.encode(group)
        let decoded = try decoder.decode(QGroup.self, from: data)
        
        #expect(decoded.id == group.id)
        #expect(decoded.name == group.name)
        #expect(decoded.$users.loaded == false)
        
        // 测试已加载状态
        try await group.$users.load(on: s).get()
        let dataLoaded = try encoder.encode(group)
        let decodedLoaded = try decoder.decode(QGroup.self, from: dataLoaded)
        
        #expect(decodedLoaded.$users.loaded == true)
        #expect(decodedLoaded.$users.ids == group.$users.ids)
    }
    
    @Test("QUserInfo 序列化和反序列化")
    func testUserInfoCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let userInfo = try await s.query(QUserInfo.self).first()
        guard let userInfo = userInfo else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 测试未加载状态
        let data = try encoder.encode(userInfo)
        let decoded = try decoder.decode(QUserInfo.self, from: data)
        
        #expect(decoded.id == userInfo.id)
        #expect(decoded.nickname == userInfo.nickname)
        #expect(decoded.$user.loaded == false)
        #expect(decoded.$alternateEmails.loaded == false)
        
        // 测试已加载状态
        try await userInfo.$user.load(on: s).get()
        try await userInfo.$alternateEmails.load(on: s).get()
        
        let dataLoaded = try encoder.encode(userInfo)
        let decodedLoaded = try decoder.decode(QUserInfo.self, from: dataLoaded)
        
        #expect(decodedLoaded.$user.loaded == true)
        #expect(decodedLoaded.$user.id == userInfo.$user.id)
        #expect(decodedLoaded.$user.wrappedValue.id == userInfo.$user.wrappedValue.id)
        
        #expect(decodedLoaded.$alternateEmails.loaded == true)
        #expect(decodedLoaded.$alternateEmails.wrappedValue.count == userInfo.$alternateEmails.wrappedValue.count)
    }
    
    @Test("QInfoSlice 序列化和反序列化")
    func testInfoSliceCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let slice = try await s.query(QInfoSlice<AlternateEmail>.self).first()
        guard let slice = slice else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(slice)
        let decoded = try decoder.decode(QInfoSlice<AlternateEmail>.self, from: data)
        
        #expect(decoded.id == slice.id)
        #expect(decoded.$userInfo.id == slice.$userInfo.id)
        #expect(decoded.$userInfo.loaded == false)
        
        try await slice.$userInfo.load(on: s).get()
        let dataLoaded = try encoder.encode(slice)
        let decodedLoaded = try decoder.decode(QInfoSlice<AlternateEmail>.self, from: dataLoaded)
        
        #expect(decodedLoaded.$userInfo.loaded == true)
        #expect(decodedLoaded.$userInfo.wrappedValue.id == slice.$userInfo.wrappedValue.id)
    }
    
    @Test("QPolicy 序列化和反序列化")
    func testPolicyCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let policy = try await s.query(QPolicy<Domain>.self).first()
        guard let policy = policy else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(policy)
        let decoded = try decoder.decode(QPolicy<Domain>.self, from: data)
        
        #expect(decoded.id == policy.id)
        #expect(decoded.$parent.loaded == false)
        // Parent 是 SuperProperty
        let pid = policy.$parent.id
        #expect(decoded.$parent.id == pid)
        try await policy.$parent.load(on: s).get()
        
        let dataLoaded = try encoder.encode(policy)
        let decodedLoaded = try decoder.decode(QPolicy<Domain>.self, from: dataLoaded)
        #expect(decodedLoaded.$parent.loaded == true)
        #expect(decodedLoaded.$parent.wrappedValue.id == policy.$parent.wrappedValue.id)
    }
    
    @Test("QUser 序列化和反序列化")
    func testUserCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let user = try await s.query(QUser.self).first()
        guard let user = user else { return }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(user)
        let decoded = try decoder.decode(QUser.self, from: data)
        
        #expect(decoded.id == user.id)
        #expect(decoded.$info.loaded == false)
        #expect(decoded.$roles.loaded == false)
        
        try await user.$roles.load(on: s).get()
        let dataLoaded = try encoder.encode(user)
        let decodedLoaded = try decoder.decode(QUser.self, from: dataLoaded)
        
        #expect(decodedLoaded.$roles.loaded == true)
        #expect(decodedLoaded.$roles.ids == user.$roles.ids)
    }
    
    @Test("混合复杂的嵌套关联加载转码测试")
    func testComplexNestedCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 找出一个 user
        let user = try await s.query(QUser.self).first()
        guard let user = user else { return }
        
        // 加载它的 groups
        try await user.$groups.load(on: s).get()
        guard let firstGroup = user.$groups.wrappedValue.first else { return }
        
        // 再加载其中一个 group 的 domains 和 users
        try await firstGroup.$domains.load(on: s).get()
        try await firstGroup.$users.load(on: s).get()
        
        // 加载 user 的 info
        try await user.$info.load(on: s).get()
        // 再进一步加载 info 的 alternateEmails
        if let info = user.$info.wrappedValue {
            try await info.$alternateEmails.load(on: s).get()
        }
        
        // 进行转码
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(user)
        
        let json = try decoder.decode([String: AnyCodable].self, from: data)
        
        print(formatJson(json))
        
        let decoded = try decoder.decode(QUser.self, from: data)
        
        // 验证第一层属性
        #expect(decoded.id == user.id)
        #expect(decoded.$roles.loaded == false) // 未加载的仍是未加载
        #expect(decoded.$groups.loaded == true)
        #expect(decoded.$info.loaded == true)
        #expect(decoded.$groups.wrappedValue.count == user.$groups.wrappedValue.count)
        
        // 验证 info 深层属性
        if let decodedInfo = decoded.$info.wrappedValue {
            #expect(decodedInfo.$alternateEmails.loaded == true)
        }
        
        // 验证深层属性
        guard let decodedFirstGroup = decoded.$groups.wrappedValue.first(where: { $0.id == firstGroup.id }) else {
            Issue.record("未找到对应的第一组")
            return
        }
        
        #expect(decodedFirstGroup.$domains.loaded == true)
        #expect(decodedFirstGroup.$users.loaded == true)
        #expect(decodedFirstGroup.$users.wrappedValue.count == firstGroup.$users.wrappedValue.count)
        #expect(decodedFirstGroup.$domains.wrappedValue.count == firstGroup.$domains.wrappedValue.count)
        
        // 未加载的属性是否确实未加载
        #expect(decodedFirstGroup.$roles.loaded == false)
    }
    
    @Test("混合复杂的 Token 与深层 User 属性级联序列化测试")
    func testComplexTokenCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let token = try await s.query(QToken.self).first()
        guard let token = token else { return }
        
        try await token.$user.load(on: s).get()
        try await token.$user.wrappedValue.$roles.load(on: s).get()
        try await token.$user.wrappedValue.$domains.load(on: s).get()
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(token)
        let decoded = try decoder.decode(QToken.self, from: data)
        
        #expect(decoded.$user.loaded == true)
        let user = decoded.$user.wrappedValue
        #expect(user.$roles.loaded == true)
        #expect(user.$domains.loaded == true)
        #expect(user.$groups.loaded == false)
        #expect(user.$info.loaded == false)
        
        #expect(user.$roles.wrappedValue.count == token.$user.wrappedValue.$roles.wrappedValue.count)
        #expect(user.$domains.wrappedValue.count == token.$user.wrappedValue.$domains.wrappedValue.count)
    }
    
    @Test("混合复杂的 Role 与 Group/User 深层分支加载序列化测试")
    func testComplexRoleCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        let role = try await s.query(QRole.self).first()
        guard let role = role else { return }
        
        try await role.$groups.load(on: s).get()
        try await role.$users.load(on: s).get()
        
        if let firstGroup = role.$groups.wrappedValue.first {
            try await firstGroup.$domains.load(on: s).get()
        }
        
        if let firstUser = role.$users.wrappedValue.first {
            try await firstUser.$info.load(on: s).get()
        }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(role)
        let decoded = try decoder.decode(QRole.self, from: data)
        
        #expect(decoded.$groups.loaded == true)
        #expect(decoded.$users.loaded == true)
        #expect(decoded.$policies.loaded == false)
        
        if let decodedFirstGroup = decoded.$groups.wrappedValue.first {
            #expect(decodedFirstGroup.$domains.loaded == true)
            #expect(decodedFirstGroup.$users.loaded == false)
        }
        
        if let decodedFirstUser = decoded.$users.wrappedValue.first {
            #expect(decodedFirstUser.$info.loaded == true)
            #expect(decodedFirstUser.$groups.loaded == false)
        }
    }
    
    @Test("混合复杂的 Policy 跨模块深层加载序列化测试")
    func testComplexPolicyCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let policies = try await s.query(QPolicy<Domain>.self).all()
        guard let policy = policies.first else { return }
        
        try await policy.$parent.load(on: s).get()
        let parentDomain = policy.$parent.wrappedValue
        try await parentDomain.$users.load(on: s).get()
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(policy)
        let decoded = try decoder.decode(QPolicy<Domain>.self, from: data)
        
        #expect(decoded.$parent.loaded == true)
        let decodedParent = decoded.$parent.wrappedValue
        #expect(decodedParent.id == parentDomain.id)
        #expect(decodedParent.$users.loaded == true)
        #expect(decodedParent.$users.wrappedValue.count == parentDomain.$users.wrappedValue.count)
    }
    
    @Test("大范围的数组批量模型序列化与深层验证")
    func testComplexArrayCodable() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 获取一批 User，比如前 3 个
        let users = try await s.query(QUser.self).all()
        let targetUsers = Array(users.prefix(3))
        guard !targetUsers.isEmpty else { return }
        
        // 分别加载不同属性以制造状态差异
        for (index, user) in targetUsers.enumerated() {
            if index % 2 == 0 {
                try await user.$roles.load(on: s).get()
                if let role = user.$roles.wrappedValue.first {
                    try await role.$policies.load(on: s).get()
                }
            } else {
                try await user.$groups.load(on: s).get()
                try await user.$info.load(on: s).get()
            }
        }
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(targetUsers)
        let decodedUsers = try decoder.decode([QUser].self, from: data)
        
        #expect(decodedUsers.count == targetUsers.count)
        
        for (index, decodedUser) in decodedUsers.enumerated() {
            let originalUser = targetUsers[index]
            #expect(decodedUser.id == originalUser.id)
            
            if index % 2 == 0 {
                #expect(decodedUser.$roles.loaded == true)
                #expect(decodedUser.$groups.loaded == false)
                #expect(decodedUser.$info.loaded == false)
                
                if let decodedRole = decodedUser.$roles.wrappedValue.first {
                    #expect(decodedRole.$policies.loaded == true)
                }
            } else {
                #expect(decodedUser.$roles.loaded == false)
                #expect(decodedUser.$groups.loaded == true)
                #expect(decodedUser.$info.loaded == true)
            }
        }
    }
    
    @Test("测试从 Json Decode")
    func decodeFromJson() async throws {
        let tokenJson = Generator.fakeTokenData
        let data = try JSONEncoder().encode(tokenJson)
        let token = try JSONDecoder().decode(QToken.self, from: data)
        
        #expect(token.credential == Generator.credential)
        #expect(token.token == Generator.token)
        #expect(token.$user.id == Generator.userId)
        #expect(token.valid == true)
        #expect(token.expireAfter == 7 * 24 * 60)
        
        // 校验 user 是否正确加载
        #expect(token.$user.loaded == true)
        #expect(token.$user.id == Generator.userId)
        
        let user = token.$user.wrappedValue
        #expect(user.id == Generator.userId)
        #expect(user.email == "user@testing.com")
        
        // 校验 user 下的各项关联是否被正确解析为其指定的未加载或已加载状态
        #expect(user.$info.loaded == true)
        #expect(user.$token.loaded == false)
        #expect(user.$groups.loaded == false)
        #expect(user.$roles.loaded == false)
        #expect(user.$domains.loaded == false)
        
        guard let info = user.$info.wrappedValue else {
            Issue.record("UserInfo 必须非空")
            return
        }
        
        #expect(info.id == Generator.infoId)
        #expect(info.nickname == "Hello World")
        #expect(info.identifier == "FAKE0392818203815")
        
        #expect(info.$user.loaded == false)
        #expect(info.$alternateEmails.loaded == true)
        #expect(info.$phones.loaded == true)
        #expect(info.$addresses.loaded == true)
        
        // 校验 Emails Slice
        let emails = info.$alternateEmails.wrappedValue
        #expect(emails.count == 1)
        #expect(emails[0].id == Generator.emailIds[0])
        #expect(emails[0].value == Generator.emails[0])
        #expect(emails[0].order == 0)
        #expect(emails[0].summary == "the secondary email address")
        #expect(emails[0].$userInfo.loaded == false)
        
        // 校验 Phones Slice
        let phones = info.$phones.wrappedValue
        #expect(phones.count == 2)
        #expect(phones[0].id == Generator.phoneIds[0])
        #expect(phones[0].value == Generator.phones[0])
        #expect(phones[0].order == 0)
        #expect(phones[1].id == Generator.phoneIds[1])
        #expect(phones[1].value == Generator.phones[1])
        #expect(phones[1].order == 1)
        
        // 校验 Addresses Slice
        let addresses = info.$addresses.wrappedValue
        #expect(addresses.isEmpty)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}

enum Generator: Sendable {
    static let credential = "0rZ5GsQqysbOvm/Ya7+QhA=="
    static let token = "4r0MHtw29zNz+DfyDo8Bzvn02kyoewqYNndSo38AuLY="
    
    static let tokenId = UUID(uuidString: "F387F90B-5E1B-44DF-A2CD-67F3C3AA2BC1")!
    static let userId = UUID(uuidString: "8FB83B07-7FA3-4954-A981-BA35AF74653C")!
    static let infoId = UUID(uuidString: "BE3BCBE7-B127-49DC-9752-BBD0E00D01C1")!
    static let emailIds = [UUID(uuidString: "A7851C53-B49C-403B-A7AA-825D71158304")!]
    static let phoneIds = [UUID(uuidString: "242BE4E2-9A6E-4D7C-A3F2-0742F91EF3F1")!, UUID(uuidString: "91596272-EF53-4104-B0BD-1C6A68A80FF4")!]
    
    static let emails = ["testing@fake.gmail.com"]
    static let phones = ["1234567890921", "8319210398123"]
    
    static let fakeTokenData: [String: AnyCodable] = {
        [
            "id": AnyCodable(tokenId),
            "user_id": AnyCodable(userId),
            "credential": AnyCodable(credential),
            "token": AnyCodable(token),
            "valid": true,
            "expire_after": AnyCodable(7 * 24 * 60),
            "created_at": AnyCodable(Date()),
            "user": [
                "id": userId,
                "loaded": true,
                "value": [
                    "id": userId,
                    "email": "user@testing.com",
                    "created_at": Date(),
                    "updated_at": Date(),
                    "info": [
                        "loaded": true,
                        "value": [
                            "id": infoId,
                            "user_id": userId,
                            "nickname": "Hello World",
                            "identifier": "FAKE0392818203815",
                            "birthday": Date(),
                            "created_at": Date(),
                            "updated_at": Date(),
                            "user": [
                                "loaded": false,
                                "value": nil
                            ],
                            "alternate_emails": [
                                "loaded": true,
                                "value": [
                                    [
                                        "id": emailIds[0],
                                        "value": emails[0],
                                        "order": UInt16(0),
                                        "summary": "the secondary email address",
                                        "created_at": Date(),
                                        "updated_at": Date(),
                                        "user_info_id": infoId,
                                        "user_info": [
                                            "loaded": false,
                                            "value": nil
                                        ]
                                    ]
                                ]
                            ],
                            "phones": [
                                "loaded": true,
                                "value": [
                                    [
                                        "id": phoneIds[0],
                                        "value": phones[0],
                                        "order": UInt16(0),
                                        "summary": "my personal phone number",
                                        "created_at": Date(),
                                        "updated_at": Date(),
                                        "user_info_id": infoId,
                                        "user_info": [
                                            "loaded": false,
                                            "value": nil
                                        ]
                                    ], [
                                        "id": phoneIds[1],
                                        "value": phones[1],
                                        "order": UInt16(1),
                                        "summary": "placeholder phone number",
                                        "created_at": Date(),
                                        "updated_at": Date(),
                                        "user_info_id": infoId,
                                        "user_info": [
                                            "loaded": false,
                                            "value": nil
                                        ]
                                    ]
                                ]
                            ],
                            "addresses": [
                                "loaded": true,
                                "value": []
                            ]
                        ]
                    ],
                    "token": [
                        "loaded": false,
                        "value": nil
                    ],
                    "groups": [
                        "loaded": false,
                        "value": nil,
                        "ids_loaded": false,
                        "ids": nil
                    ],
                    "roles": [
                        "loaded": false,
                        "value": nil,
                        "ids_loaded": false,
                        "ids": nil
                    ],
                    "domains": [
                        "loaded": false,
                        "value": nil,
                        "ids_loaded": false,
                        "ids": nil
                    ]
                ]
            ]
        ]
    }()
}
