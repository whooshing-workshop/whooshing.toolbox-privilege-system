import Testing
import ErrorHandle
import NIOCore
import AsyncAlgorithms
import Foundation
@testable import PrivilegeSystem

//@Suite("PrivilegeSystem 测试集", .serialized, .enabled(if: TestingShared.dbListening))
@Suite("PrivilegeSystem 测试集", .serialized)
struct PrivilegeSystemTests {
//    @Test("Tests")
//    func tests() async throws {
//        _ = try await TestingShared.getSystem()
//    }
    
    @Test
    func ttt() {
        var t = TTTesting()
        t.testing = "HELLOWORLD!"
        print(t.testing ?? "NILL")
        t.testing = nil
        print(t.testing ?? "NILL")
        t.$testing = nil
    }
}

@propertyWrapper
struct PPassive<T>: @unchecked Sendable {
    private var value: T? = nil
    
    public var wrappedValue: T {
        get {
            guard let v = value else { fatalError("该属性值未被赋值，不可获取未被赋值的属性值") }
            return v
        }
        set { value = newValue }
    }
    
    public internal(set) var projectedValue: T? {
        get { value }
        set { value = newValue }
    }
    
    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    public init() {}
}

struct TTTesting {
    @PPassive() var testing: String?
    
    init() {
        testing = nil
    }
}
