import Testing
import ErrorHandle
import NIOCore
import NIOPosix
import NIO
import Cryptos
import NIOFileSystem
import Foundation
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
    
    static let userInGroups: [Int: [Int]] = [
        0: [1, 2, 4],
        1: [3, 5],
        2: [],
        3: [0],
        4: [5],
        5: [0, 1, 2, 3, 4, 5],
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
    
    static let domainForGroup: [Int: [Int]] = [
        0: [0],
        1: [1, 2],
        2: [3, 4],
        3: [5],
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
    
    static let roleForGroupUser: [Int: [(Int, Int)]] = [
        3: [(0, 2)],
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
        
        let s = try await PrivilegeSystem(
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "woo", password: "testing", database: "privilege_system", tls: .disable),
            opaConfigure: .init(host: opaHost, port: opaPort, proxy: .server(host: "localhost", port: 9090)),
            logger: .init(label: "Privilege-System-Testing"),
            debuging: .init(tdeEncrypt: false)
        )
        
        let m = try await PrivilegeModule<ResourceList>(
            moduleId: UUID(uuidString: "B7E2A9D0-4F3B-4C1E-8D2A-9B7C6E5F4D32")!,
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "woo", password: "testing", database: "privilege_module", tls: .disable),
            opaConfigure: .init(host: opaHost, port: opaPort, proxy: .server(host: "localhost", port: 9090)),
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
