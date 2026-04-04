import Cryptos
import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
import Query
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
    }
    
    @Test("自定义查询")
    func customQuery() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let infos = try await s.infoSlice.fetch(for: AT.ids[0]).get()
        #expect(infos.addresses == Self.infos[0].2.addresses)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .userInfo
    }
}
