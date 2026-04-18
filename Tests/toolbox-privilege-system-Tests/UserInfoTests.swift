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

@Suite("用户信息 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct UserinfoTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .userInfo {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    nonisolated(unsafe) static var ids: OrderedDictionary<UUID, (addrs: [UUID], emails: [UUID], phones: [UUID])> = [:]
    
    static var infos: [(UUID, PUserInfo, PExtendedInfo)] {[
        (
            AT.ids[0],
            PUserInfo(
                nickname: "HelloWorld",
                identifier: "fake142703198703210832",
                birthday: .init(timeIntervalSince1970: 1000000000)
            ),
            PExtendedInfo(
                addresses: [
                    .init(value: "Philippines", order: 0),
                    .init(value: "Iloilo", order: 1),
                    .init(value: "Molo", order: 2, description: "Final location")
                ],
                alternateEmails: [
                    .init(value: "testing@example.com", order: 0, description: "Testing email"),
                    .init(value: "testing@qq.com", order: 1)
                ],
                phones: [
                    .init(value: "+8618277382119", order: 0),
                    .init(value: "+639276382839", order: 1, description: "Philippines phone number")
                ]
            )
        ), (
            AT.ids[3],
            PUserInfo(
                nickname: "lol",
                identifier: "fake2719201093758192",
                birthday: .init(timeIntervalSince1970: 38192919012)
            ),
            PExtendedInfo(
                addresses: [
                    .init(value: "China", order: 0),
                    .init(value: "Sichuan Province", order: 1, description: "the province")
                ],
                alternateEmails: [
                    .init(value: "lol@example.com", order: 0),
                    .init(value: "interesting@icloud.com", order: 1, description: "only for testing")
                ],
                phones: [
                    .init(value: "+193810928375", order: 8),
                    .init(value: "+2819182375091", order: 9)
                ]
            )
        ), (
            AT.ids[4],
            PUserInfo(
                nickname: "TechEnthusiast",
                identifier: "fake35198220010915723X",
                birthday: .init(timeIntervalSince1970: 984614400) // 2001
            ),
            PExtendedInfo(
                addresses: [
                    .init(value: "Japan", order: 0),
                    .init(value: "Tokyo", order: 1),
                    .init(value: "Akihabara", order: 2, description: "Office location")
                ],
                alternateEmails: [
                    .init(value: "tech_dev@sony.jp", order: 0, description: "Work email"),
                    .init(value: "gamer_soul@gmail.com", order: 1)
                ],
                phones: [
                    .init(value: "+819012345678", order: 0, description: "Mobile JP")
                ]
            )
        ),
        (
            AT.ids[5],
            PUserInfo(
                nickname: "NomadTraveler",
                identifier: "fake441205199505204412",
                birthday: .init(timeIntervalSince1970: 800928000) // 1995
            ),
            PExtendedInfo(
                addresses: [
                    .init(value: "Thailand", order: 0),
                    .init(value: "Chiang Mai", order: 1, description: "Digital nomad hub"),
                    .init(value: "Nimman Road", order: 2)
                ],
                alternateEmails: [
                    .init(value: "traveler@protonmail.com", order: 0, description: "Secure contact")
                ],
                phones: [
                    .init(value: "+66812345678", order: 0),
                    .init(value: "+447712345678", order: 1, description: "UK roaming SIM")
                ]
            )
        ),
        (
            AT.ids[1],
            PUserInfo(
                nickname: "Silversurfer",
                identifier: "fake110101196001018821",
                birthday: .init(timeIntervalSince1970: -315619200) // 1960
            ),
            PExtendedInfo(
                addresses: [
                    .init(value: "United States", order: 0),
                    .init(value: "California", order: 1),
                    .init(value: "Mountain View", order: 2, description: "Home")
                ],
                alternateEmails: [
                    .init(value: "legacy_user@aol.com", order: 0),
                    .init(value: "backup_admin@icloud.com", order: 1, description: "Recovery only")
                ],
                phones: [
                    .init(value: "+16505550199", order: 0)
                ]
            )
        )
    ]}
    
    static var updates: [(
        (PUserInfo.Updater, String, @Sendable (QUserInfo) -> Bool)?,
        (PAddressSlice.Updater, String, @Sendable (QAddressSlice) -> Bool)?,
        (PAlternateEmailSlice.Updater, String, @Sendable (QAlternateEmailSlice) -> Bool)?,
        (PPhoneSlice.Updater, String, @Sendable (QPhoneSlice) -> Bool)?
    )] {[
        (
            (
                .init(userInfoId: Self.ids.keys[0]).update(identifier: "changed1234567890"),
                "User_1 userinfo",
                { $0.identifier == "changed1234567890" }
            ),
            nil,
            (
                .init(infoSliceId: Self.ids.values[0].emails[0]).update(value: "updatedexample@example.com"),
                "User_1 email slice",
                { $0.value == "updatedexample@example.com" }
            ),
            nil
        ),
        (
            nil,
            (
                .init(infoSliceId: Self.ids.values[1].addrs[1]).update(value: "Updated Sichuan Province"),
                "User_2 address slice 1",
                { $0.value == "Updated Sichuan Province" }
            ),
            nil,
            (
                .init(infoSliceId: Self.ids.values[1].phones[0]).update(value: "+000000000001"),
                "User_2 phone slice 0",
                { $0.value == "+000000000001" }
            )
        ),
        (
            (
                .init(userInfoId: Self.ids.keys[2]).update(nickname: "UpdatedTechEnthu"),
                "User_3 userinfo",
                { $0.nickname == "UpdatedTechEnthu" }
            ),
            nil,
            (
                .init(infoSliceId: Self.ids.values[2].emails[1]).update(value: "updated_gamer_soul@gmail.com"),
                "User_3 email slice 1",
                { $0.value == "updated_gamer_soul@gmail.com" }
            ),
            nil
        ),
        (
            nil,
            (
                .init(infoSliceId: Self.ids.values[3].addrs[2]).update(value: "Updated Nimman Road"),
                "User_4 address slice 2",
                { $0.value == "Updated Nimman Road" }
            ),
            nil,
            (
                .init(infoSliceId: Self.ids.values[3].phones[0]).update(value: "+66800000000"),
                "User_4 phone slice 0",
                { $0.value == "+66800000000" }
            )
        )
    ]}
    
    @Test("创建用户信息")
    func create() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        try await s.userInfo.create { Self.infos }.get()
    }
    
    @Test("查询用户信息")
    func query() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        #expect(try await QUserInfo.query(on: s).count().get() == Self.infos.count)
        #expect(try await QAddressSlice.query(on: s).count().get() == Self.infos.reduce(0) { $0 + $1.2.addresses.count })
        #expect(try await QAlternateEmailSlice.query(on: s).count().get() == Self.infos.reduce(0) { $0 + $1.2.alternateEmails.count })
        #expect(try await QPhoneSlice.query(on: s).count().get() == Self.infos.reduce(0) { $0 + $1.2.phones.count })
        
        for userInfo in Self.infos {
            let ui = try #require(
                try await s.query(QUserInfo.self)
                    .filter(\.identifier == userInfo.1.identifier)
                    .first()
                    .get()
            )
            
            var addresses: [UUID] = []
            var emails: [UUID] = []
            var phones: [UUID] = []
            
            for address in userInfo.2.addresses {
                let addr = try #require(
                    try await s.query(QAddressSlice.self)
                        .filter(\.value == address.value)
                        .first()
                        .get()
                )
                
                addresses.append(addr.id)
            }
            
            for email in userInfo.2.alternateEmails {
                let e = try #require(
                    try await s.query(QAlternateEmailSlice.self)
                        .filter(\.value == email.value)
                        .first()
                        .get()
                )
                
                emails.append(e.id)
            }
            
            for phone in userInfo.2.phones {
                let p = try #require(
                    try await s.query(QPhoneSlice.self)
                        .filter(\.value == phone.value)
                        .first()
                        .get()
                )
                
                phones.append(p.id)
            }
            
            Self.ids[ui.id] = (addresses, emails, phones)
        }
        
        #expect(Self.ids.count == Self.infos.count)
    }
    
    @Test("Fetch 查询")
    func fetchQuery() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let infos = try await s.infoSlice.fetch(for: AT.ids[0]).get()
        #expect(infos.addresses == Self.infos[0].2.addresses)
        #expect(infos.alternateEmails == Self.infos[0].2.alternateEmails)
        #expect(infos.phones == Self.infos[0].2.phones)
    }
    
    @Test("自定义查询")
    func customQuery() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for info in Self.infos {
            for address in info.2.addresses {
                let res = try #require(
                    try await QUserInfo.query(on: s)
                        .join(QAddressSlice.self, on: \QUserInfo.id == \QAddressSlice.userInfoId)
                        .filter(QAddressSlice.self, \.value == address.value)
                        .first()
                        .get()
                )
                
                #expect(res.nickname == info.1.nickname)
                #expect(res.identifier == info.1.identifier)
            }
            
            for email in info.2.alternateEmails {
                let res = try #require(
                    try await QUserInfo.query(on: s)
                        .join(QAlternateEmailSlice.self, on: \QUserInfo.id == \QAlternateEmailSlice.userInfoId)
                        .filter(QAlternateEmailSlice.self, \.value == email.value)
                        .first()
                        .get()
                )
                
                #expect(res.nickname == info.1.nickname)
                #expect(res.identifier == info.1.identifier)
            }
            
            for phone in info.2.phones {
                let res = try #require(
                    try await QUserInfo.query(on: s)
                        .join(QPhoneSlice.self, on: \QUserInfo.id == \QPhoneSlice.userInfoId)
                        .filter(QPhoneSlice.self, \.value == phone.value)
                        .first()
                        .get()
                )
                
                #expect(res.nickname == info.1.nickname)
                #expect(res.identifier == info.1.identifier)
            }
        }
    }
    
    @Test("数据更新")
    func update() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        for (infoUpdate, addressUpdate, emailUpdate, phoneUpdate) in Self.updates {
            if let iu = infoUpdate {
                let res = try await s.userInfo.update(with: iu.0).get()
                #expect(iu.2(res), .init(stringLiteral: iu.1))
            }

            if let au = addressUpdate {
                let res = try await s.infoSlice.update(with: au.0).get()
                #expect(au.2(res), .init(stringLiteral: au.1))
            }
            
            if let eu = emailUpdate {
                let res = try await s.infoSlice.update(with: eu.0).get()
                #expect(eu.2(res), .init(stringLiteral: eu.1))
            }
            
            if let pu = phoneUpdate {
                let res = try await s.infoSlice.update(with: pu.0).get()
                #expect(pu.2(res), .init(stringLiteral: pu.1))
            }
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .userInfo
    }
}
