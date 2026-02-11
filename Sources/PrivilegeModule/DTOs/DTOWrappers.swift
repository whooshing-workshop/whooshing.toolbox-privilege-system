import Foundation
import Fluent
import PgSQL
import Collections
import NIOConcurrencyHelpers

public enum DTO {}

public extension DTO {
    protocol Status: Sendable {}
    
    enum Prepare: Status {}
    enum Queried: Status {}
    
    @propertyWrapper
    struct Passive<T: Sendable & Codable>: @unchecked Sendable, Codable {
        private var value: T?
        private let lock = NIOLock()
        
        public var wrappedValue: T {
            get {
                lock.withLock {
                    guard let v = value else { fatalError("该属性值未被赋值，不可获取未被赋值的属性值") }
                    return v
                }
            }
            set {
                lock.withLock { value = newValue }
            }
        }
        
        public package(set) var projectedValue: T? {
            get {
                lock.withLock { value }
            }
            set {
                lock.withLock { value = newValue }
            }
        }
        
        public init(wrappedValue: T) {
            self.value = wrappedValue
        }
        
        public init() {
            self.value = nil
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.value = try container.decode(T.self)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(wrappedValue)
        }
    }
    
    @propertyWrapper
    struct Protect<T: Sendable>: @unchecked Sendable {
        private var value: T?
        private let lock = NIOLock()
        
        public var wrappedValue: T {
            get {
                lock.withLock {
                    guard let v = value else { fatalError("该属性值被保护(隐藏)，不可获取") }
                    return v
                }
            }
            set {
                lock.withLock { value = newValue }
            }
        }
        
        public package(set) var projectedValue: T? {
            get {
                lock.withLock { value }
            }
            set {
                lock.withLock { value = newValue }
            }
        }
        
        public init(wrappedValue: T) {
            self.value = wrappedValue
        }
        
        public init() {
            self.value = nil
        }
    }
}

package protocol DTOUpdater: Sendable {
    associatedtype QueriedDTO: Sendable
    associatedtype DBModel: PGModel & Sendable
    associatedtype KeyPathType: AnyKeyPath
    var id: DBModel.IDValue { get }
    var updates: OrderedDictionary<
        KeyPathType,
        (QueryBuilder<DBModel>, QueriedDTO?) throws -> QueryBuilder<DBModel>
    > { get }
    var needsPeek: Bool { get }
}

package extension DTOUpdater {
    var all: [KeyPathType] { .init(updates.keys) }
}
