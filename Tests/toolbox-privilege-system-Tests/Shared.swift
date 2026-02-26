import Testing
import ErrorHandle
import NIOCore
import NIOPosix
import NIO
import Cryptos
import NIOFileSystem
import Foundation
@testable import PrivilegeSystem

enum TestingData {
    case string(String)
    case random(Int)
}

struct TestingShared {

    enum TestStage {
        case entryBasics
        case directory
        case fileAppending
        case fileInsertion
        case fileRemoving
        case fileReplacemeng
    }
     
    static let dbHost = ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"] ?? "localhost"
    static let dbPort = 5432
    static let dbListening = try! isPortOpen(host: dbHost, port: dbPort)
    
    @MainActor static var priviligeSystem: PrivilegeSystem? = nil
    @MainActor static var testStage: TestStage = .entryBasics
    
    @MainActor
    static func getSystem() async throws -> PrivilegeSystem {
        if let system = priviligeSystem {
            return system
        }
        
        let pool = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let eventLoop = pool.next()
        
        let s = try await PrivilegeSystem(
            eventLoop: eventLoop,
            dbConfigure: .init(hostname: dbHost, port: dbPort, username: "clwang", password: "testing", database: "privilege_system", tls: .disable),
            opaConfigure: .init(),
            logger: .init(label: "Privilege-System-Testing"),
            debuging: .init(tdeEncrypt: false)
        )

        self.priviligeSystem = s
        return s
    }
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
