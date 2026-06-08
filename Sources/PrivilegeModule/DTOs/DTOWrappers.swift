import Foundation
import Fluent
import PgSQL
import Collections
import NIOConcurrencyHelpers
@preconcurrency import AnyCodable

public enum DTO {}

package protocol DTOModel where AssociatedModel.IDValue == UUID {
    associatedtype AssociatedModel: PGModel
    associatedtype T: DTO.Status
    var id: UUID { get }
    var model: AssociatedModel { get }
}

package extension DTOModel {
    var model: AssociatedModel { fatalError("未保存到数据库中的 DTO 不存在 model 模型") }
}

public extension DTO {
    protocol Status: Sendable, Hashable {}
    
    enum Prepare: Status {}
    enum Queried: Status {}
    
    @propertyWrapper
    struct Passive<T: Sendable & Codable>: @unchecked Sendable, Codable {
        private var value: T?
        private let lock = NIOLock()
        
        public package(set) var wrappedValue: T {
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
    init(
        id: DBModel.IDValue,
        updates: OrderedDictionary<
            KeyPathType,
            (QueryBuilder<DBModel>, QueriedDTO?) throws -> QueryBuilder<DBModel>
        >,
        needsPeek: Bool
    )
}

package extension DTOUpdater {
    var all: [KeyPathType] { .init(updates.keys) }
    
    func generate(
        needsPeek: Bool = false,
        key: KeyPathType,
        value: @escaping (QueryBuilder<DBModel>, QueriedDTO?) throws -> QueryBuilder<DBModel>
    ) -> Self {
        var updates = updates
        updates[key] = value
        
        return .init(
            id: id,
            updates: updates,
            needsPeek: self.needsPeek || needsPeek
        )
    }
}

extension DTO.Passive: Equatable where T: Equatable {
    public static func == (lhs: DTO.Passive<T>, rhs: DTO.Passive<T>) -> Bool {
        lhs.value == rhs.value
    }
}

extension DTO.Passive: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension DTO.Protect: Equatable where T: Equatable {
    public static func == (lhs: DTO.Protect<T>, rhs: DTO.Protect<T>) -> Bool {
        lhs.value == rhs.value
    }
}

extension DTO.Protect: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}
