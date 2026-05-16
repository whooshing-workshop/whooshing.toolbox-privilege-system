import Testing
import ErrorHandle
import NIOCore
import NIOPosix
import NIO
import Cryptos
import NIOFileSystem
import Foundation
import AsyncHTTPClient
@testable import PrivilegeSystem
@testable import PrivilegeModule

struct TestingShared {

    enum TestStage {
        case account
        case group
        case role
        case domain
        case userInfo
        case relations
        case policy
        case end
    }
    
    // ---------------------------------------------------------------------------
    // 用户与群组的从属关系 (userIdx -> [groupIdx])
    // PolicyTests 关键场景:
    //   user0 -> group0 (AdministratorGroup, 绑 domain0: GlobalScope)
    //   user1 -> group1 (OperatorGroup, 绑 domain1: AsiaPacific)
    //   user2 -> group2 (DeveloperHub, 绑 domain2: NorthAmerica)
    //   user3 -> group0 + group3 (两个域, AND 全部满足)
    //   user4 -> (无 group, 纯 role 判定场景)
    //   user5 -> group0 + group1 + group2 + group3 (多域 AND 压力测试)
    // ---------------------------------------------------------------------------
    static let userInGroups: [Int: [Int]] = [
        0: [0],
        1: [1],
        2: [2],
        3: [0, 3],
        4: [],
        5: [0, 1, 2, 3],
        6: [6, 7],
        7: [8, 9],
        8: [10],
        9: [11],
        10: [12, 13],
        11: [14],
        12: [15],
        13: [6, 8, 10],
        14: [7, 9, 11],
        15: [12, 14, 15]
    ]
    
    // ---------------------------------------------------------------------------
    // 群组嵌套结构 (parentGroupIdx -> [childGroupIdx])
    // RelationTests 中通过 embed()/divorce() 建立和拆除父子关系
    // 设计原则: 子群组索引不与 userInGroups 的 group0-5 核心场景冲突
    //
    //   GT.ids[0] (AdministratorGroup)
    //       ├─ GT.ids[6]  (SalesTeam)       // 测试单父多子场景
    //       └─ GT.ids[7]  (MarketingTeam)
    //
    //   GT.ids[1] (OperatorGroup)
    //       └─ GT.ids[8]  (HumanResources)  // 测试单父单子场景
    //
    //   GT.ids[2] (DeveloperHub)
    //       ├─ GT.ids[9]  (QualityAssurance) // 测试 embed 后 divorce 清理
    //       └─ GT.ids[10] (Designers)
    // ---------------------------------------------------------------------------
    static let groupStructures: [Int: [Int]] = [
        0: [6, 7],
        1: [8],
        2: [9, 10]
    ]
    
    // ---------------------------------------------------------------------------
    // 域与群组的从属关系 (domainIdx -> [groupIdx])
    // PolicyTests 关键场景:
    //   domain0 (GlobalScope)       -> group0 (AdministratorGroup)
    //   domain1 (AsiaPacific)       -> group1 (OperatorGroup)
    //   domain2 (NorthAmerica)      -> group2 (DeveloperHub)
    //   domain3 (SandboxEnvironment)-> group3 (BannedUsers)
    // 以上四组构成 PolicyTests 中核心 judge 场景的基础
    // ---------------------------------------------------------------------------
    static let domainForGroup: [Int: [Int]] = [
        0: [0],
        1: [1],
        2: [2],
        3: [3],
        4: [6, 7],
        5: [8, 9],
        6: [10, 11],
        7: [12],
        8: [13],
        9: [14],
        10: [15],
        11: [6, 8, 10],
        12: [7, 9, 11],
        13: [12, 13, 14, 15]
    ]
    
    // 域与用户的从属关系 (domainIdx -> [groupIdx])
    static let domainForUser: [Int: [Int]] = [
        3: [4],
        0: [0],
        4: [6, 7],
        5: [8, 9],
        6: [10],
        7: [11],
        8: [12, 13],
        9: [14],
        10: [15],
        11: [6, 8],
        12: [7, 9],
        13: [10, 11, 12]
    ]
    
    // 角色与用户的从属关系 (roleIdx -> [userIdx])
    static let roleForUser: [Int: [Int]] = [
        0: [0],
        1: [1, 3],
        2: [2],
        3: [4],
        4: [6, 7],
        5: [8, 9],
        6: [10],
        7: [11],
        8: [12, 13],
        9: [14],
        10: [15],
        11: [6, 8],
        12: [7, 9],
        13: [10, 11, 12]
    ]
    
    // 角色与群组的从属关系 (roleIdx -> [groupIdx])
    static let roleForGroup: [Int: [Int]] = [
        3: [5],
        4: [6, 7],
        5: [8, 9],
        6: [10],
        7: [11],
        8: [12, 13],
        9: [14],
        10: [15],
        11: [6, 8],
        12: [7, 9],
        13: [10, 11, 12]
    ]
    
    // ---------------------------------------------------------------------------
    // 组内用户的角色指派 (roleIdx -> [(userIdx, groupIdx)])
    // 注意: (userIdx, groupIdx) 必须在 userInGroups 中有对应关系才有效
    // PolicyTests 关键场景:
    //   role3 (ObserverRole) -> user0 在 group0 中 (组内角色指派场景)
    //   role4 (SalesManager) -> user6 在 group6 中
    //   role5 (HRLead)       -> user7 在 group8 中
    // ---------------------------------------------------------------------------
    static let roleForGroupUser: [Int: [(Int, Int)]] = [
        3: [(0, 0)],
        4: [(6, 6)],
        5: [(7, 8)],
        6: [(8, 10)],
        7: [(9, 11)]
    ]
     
    static let dbHost = ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"] ?? "localhost"
    static let dbPort = Int(ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_PORT"] ?? "5432")!
    static let dbListening = try! isPortOpen(host: dbHost, port: dbPort)
    
    static let opaHost = ProcessInfo.processInfo.environment["GITHUB_OPA_TESTING_HOST"] ?? "localhost"
    static let opaPort = Int(ProcessInfo.processInfo.environment["GITHUB_OPA_TESTING_PORT"] ?? "8181")!
    static let opaListening = try! isPortOpen(host: opaHost, port: opaPort)
    
    @MainActor static var privilegeSystem: PrivilegeSystem? = nil
    @MainActor static var privilegeModule: PrivilegeModule<ResourceList>? = nil
    @MainActor static var testStage: TestStage = .account
    
    @MainActor
    static func getSystem() async throws -> (PrivilegeSystem, PrivilegeModule<ResourceList>) {
        if
            let system = privilegeSystem,
            let module = privilegeModule
        {
            return (system, module)
        }
        
        let pool = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let eventLoop = pool.next()
        
        let proxy: HTTPClient.Configuration.Proxy? = try isPortOpen(host: "localhost", port: 9090) ? .server(host: "localhost", port: 9090) : nil
        
        let s = try await PrivilegeSystem(
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "woo", password: "testing", database: "privilege_system", tls: .disable),
            opaConfigure: .init(host: opaHost, port: opaPort, proxy: proxy),
            logger: .init(label: "Privilege-System-Testing"),
            debuging: .init(tdeEncrypt: false)
        )
        
        let m = try await PrivilegeModule<ResourceList>(
            moduleId: UUID(uuidString: "B7E2A9D0-4F3B-4C1E-8D2A-9B7C6E5F4D32")!,
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "woo", password: "testing", database: "privilege_module", tls: .disable),
            opaConfigure: .init(host: opaHost, port: opaPort, proxy: proxy),
            logger: .init(label: "Privilege-Module-Testing"),
            debuging: .init(tdeEncrypt: false)
        )

        self.privilegeSystem = s
        self.privilegeModule = m
        return (s, m)
    }
}

enum ResourceList: String, ResourceTypeList {
    case file
    case directory
    case alias
}

func randomBuffer(size: Int) -> ByteBuffer {
    var buffer = ByteBufferAllocator().buffer(capacity: size)
    var rng = SystemRandomNumberGenerator()
    let randomBytes = (0..<size).map { _ in UInt8.random(in: 0...255, using: &rng) }
    buffer.writeBytes(randomBytes)
    return buffer
}

func randomData(size: Int) -> Data {
    var buffer = ByteBufferAllocator().buffer(capacity: size)
    var rng = SystemRandomNumberGenerator()
    let randomBytes = (0..<size).map { _ in UInt8.random(in: 0...255, using: &rng) }
    buffer.writeBytes(randomBytes)
    return .init(buffer: buffer)
}

func isPortOpen(host: String, port: Int, timeout: TimeAmount = .seconds(3)) throws -> Bool {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
        try? group.syncShutdownGracefully()
    }

    let promise = group.next().makePromise(of: Bool.self)

    let bootstrap = ClientBootstrap(group: group)
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

    let futureChannel = bootstrap.connect(host: host, port: port)

    group.next().scheduleTask(in: timeout) {
        promise.fail(ChannelError.connectTimeout(timeout))
    }

    futureChannel.whenSuccess { channel in
        channel.close(mode: .all, promise: nil)
        promise.succeed(true)
    }

    futureChannel.whenFailure { error in
        promise.succeed(false)
    }

    return try promise.futureResult.wait()
}
