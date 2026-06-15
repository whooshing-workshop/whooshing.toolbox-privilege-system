import Testing
import ErrorHandle
import NIOCore
import NIOPosix
import NIO
import Cryptos
import NIOFileSystem
import Foundation
import AsyncHTTPClient
import Collections
import Logging
import LoggingAdvanced
@testable import ResourceMacros
@testable import PrivilegeSystem
@testable import PrivilegeModule

typealias PModule = PrivilegeModule<ResourceList>

struct TestingShared {

    enum TestStage {
        case hashable
        case account
        case group
        case role
        case domain
        case resource
        case userInfo
        case relations
        case query
        case policy
        case advancePolicy
        case readmeExamples
        case end
    }
    
    // ---------------------------------------------------------------------------
    // 用户与群组的从属关系 (userIdx -> [groupIdx])
    // PolicyTests 关键场景:
    //   user0 -> group0 (AdministratorGroup, 绑 domain0: GlobalScope)
    //   user1 -> group1 (OperatorGroup, 绑 domain1: AsiaPacific)
    //   user2 -> group2 (DeveloperHub, 绑 domain2: NorthAmerica)
    //   user3 -> group0 + group3 (两个群组域 + 用户直接域, AND 全部满足)
    //   user4 -> (无 group, 但有用户直接域)
    //   user5 -> group0 + group1 + group2 + group3 (多域 AND 压力测试)
    // ---------------------------------------------------------------------------
    static let userInGroups: OrderedDictionary<Int, [Int]> = [
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
    static let groupStructures: OrderedDictionary<Int, [Int]> = [
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
    static let domainForGroup: OrderedDictionary<Int, [Int]> = [
        0: [0],
        1: [1],
        2: [2],
        3: [3],
        4: [6, 7]
    ]
    
    // 域与用户的从属关系 (domainIdx -> [userIdx])
    // PolicyTests 关键场景:
    //   user0 <- domain0              // 用户直接域 + 群组域重叠
    //   user3 <- domain4              // 双群组域之外，再叠加一个默认放行直接域
    //   user4 <- domain6 + domain7    // 无 group 用户仍有 domain reports
    //   user5 <- domain8 + domain9    // 四群组域压力测试之外，再叠加两个直接域
    static let domainForUser: OrderedDictionary<Int, [Int]> = [
        0: [0],
        4: [3],
        6: [4],
        7: [4],
        8: [5],
        9: [5]
    ]
    
    // 角色与用户的从属关系 (roleIdx -> [userIdx])
    // 注意: 这里的 key 是 role index，不是 user index。
    // PolicyTests 关键场景:
    //   user0 <- RT[0]
    //   user1 <- RT[1] + RT[3]
    //   user2 <- RT[2]
    //   user3 <- RT[4]
    //   user4 <- RT[6] + RT[7]
    //   user5 <- RT[8] + RT[9]
    //   user6 <- RT[10]
    //   user7 <- RT[11]
    //   user8 <- RT[12] + RT[13]
    static let roleForUser: OrderedDictionary<Int, [Int]> = [
        0: [0],
        1: [1],
        2: [2],
        3: [1],
        4: [3],
        6: [4],
        7: [4],
        8: [5],
        9: [5],
        10: [6],
        11: [7],
        12: [8],
        13: [8]
    ]
    
    // 角色与群组的从属关系 (roleIdx -> [groupIdx])
    // 群组角色会对该群组及其子群组用户生效。
    static let roleForGroup: OrderedDictionary<Int, [Int]> = [
        3: [5],
        4: [6, 7],
        5: [3],
        6: [10],
        11: [0]
    ]
    
    // ---------------------------------------------------------------------------
    // 组内用户的角色指派 (roleIdx -> [(userIdx, groupIdx)])
    // 注意: (userIdx, groupIdx) 必须在 userInGroups 中有对应关系才有效
    // PolicyTests 关键场景:
    //   role3 (ObserverRole) -> user0 在 group0 中 (组内角色指派场景)
    //   role4 (SalesManager) -> user6 在 group6 中
    //   role5 (HRLead)       -> user7 在 group8 中
    // ---------------------------------------------------------------------------
    static let roleForGroupUser: OrderedDictionary<Int, [(Int, Int)]> = [
        3: [(0, 0)],
        4: [(6, 6)],
        5: [(7, 8)],
        6: [(8, 10)],
        7: [(9, 11)]
    ]
     
    static let dbHost = ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"] ?? "localhost"
    static let dbPort = Int(ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_PORT"] ?? "5432")!
    static let dbListening = try! isPortOpen(host: dbHost, port: dbPort)
    
    static let opaHost = ProcessInfo.processInfo.environment["GITHUB_EOPA_TESTING_HOST"] ?? "localhost"
    static let opaPort = Int(ProcessInfo.processInfo.environment["GITHUB_EOPA_TESTING_PORT"] ?? "8181")!
    static let opaListening = try! isPortOpen(host: opaHost, port: opaPort)
    
    @MainActor static var privilegeSystem: PrivilegeSystem? = nil
    @MainActor static var privilegeModule: PrivilegeModule<ResourceList>? = nil
    @MainActor static var testStage: TestStage = .hashable
    @MainActor static let loggingSystem: Void = {
        LoggingFactory(strategies: [
            .init(label: "Console", level: .trace)
        ]).bootstrap()
    }()
    
    @MainActor
    static func getSystem() async throws -> (PrivilegeSystem, PrivilegeModule<ResourceList>) {
        if
            let system = privilegeSystem,
            let module = privilegeModule
        {
            return (system, module)
        }
        
        _ = loggingSystem
        
        let pool = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let eventLoop = pool.next()
        
        let proxy: HTTPClient.Configuration.Proxy? = try isPortOpen(host: "localhost", port: 9090) ? .server(host: "localhost", port: 9090) : nil
        
        var sysLogger = Logger(label: "Privilege-System-Testing")
        var modLogger = Logger(label: "Privilege-Module-Testing")
        
        sysLogger.logLevel = .debug
        modLogger.logLevel = .debug
        
        let s = try await PrivilegeSystem(
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "woo", password: "testing", database: "privilege_system", tls: .disable),
            opaConfigure: .init(host: opaHost, port: opaPort, proxy: proxy),
            logger: sysLogger,
            debuging: .init(tdeEncrypt: false)
        )
        
        let m = try await PrivilegeModule<ResourceList>(
            moduleId: UUID(uuidString: "B7E2A9D0-4F3B-4C1E-8D2A-9B7C6E5F4D32")!,
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "woo", password: "testing", database: "privilege_module", tls: .disable),
            opaConfigure: .init(host: opaHost, port: opaPort, proxy: proxy),
            logger: modLogger,
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
    case json
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
