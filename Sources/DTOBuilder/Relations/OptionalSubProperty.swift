import Foundation
import Query

public extension DTO.DBModel {
    typealias OptionalSub<To> = OptionalSubProperty<Self, To>
        where To: DTO.DBModel
}

// 需要隐式传递模型的 id 主键值
// self.$<sub>.fromId == XXX
@propertyWrapper
final public class OptionalSubProperty<From, To>: @unchecked Sendable
    where
        From: DTO.DBModel,
        To: DTO.DBModel
{
    public var projectedValue: OptionalSubProperty<From, To> { self }
    
    public var wrappedValue: To? {
        lock.withLock {
            guard __loaded else {
                fatalError("\(Self.logName) 未加载，请调用 $ 前缀后调用 load(on:) 函数后再取得加载后的内容")
            }
            
            return __value
        }
    }
    
    public var loaded: Bool {
        lock.withLock { __loaded }
    }
    
    package var fromId: UUID {
        get {
            lock.withLock {
                guard let id = __fromId else {
                    fatalError("模型的 id 主键值 未赋值")
                }
                
                return id
            }
        }
        set { lock.withLock { __fromId = newValue } }
    }
    
    let parentKeyPath: KeyPath<To, To.Super<From>>
    
    private var __loaded: Bool = false
    private var __value: To? = nil
    private var __fromId: UUID? = nil           // 模型本体的 id 主键
    private let lock = NIOLock()
    
    public init(
        for parentKey: KeyPath<To, To.Super<From>>
    ) {
        self.parentKeyPath = parentKey
    }
    
    public func inject(_ value: To?) {
        lock.withLock {
            __loaded = true
            __value = value
        }
    }
    
    public func get(on system: Query.System) -> EventLoopRes<To?, DTO.Errcase> {
        guard let sys = system as? __QuerySystem else {
            fatalError("传入的实例并非 PrivilegeSystem 或 PrivilegeModule: \(type(of: system))")
        }
        return self.get(on: sys.pgDB)
    }
    
    public func load(on system: Query.System) -> EventLoopRes<Void, DTO.Errcase> {
        guard let sys = system as? __QuerySystem else {
            fatalError("传入的实例并非 PrivilegeSystem 或 PrivilegeModule: \(type(of: system))")
        }
        return self.load(on: sys.pgDB)
    }
}

package extension OptionalSubProperty {
    func get(on db: PGDatabase) -> EventLoopRes<To?, DTO.Errcase> {
        To.query(on: db)
            .filter(parentKeyPath.appending(path: \.id) == self.fromId)
            .all()
            .errCast(DTO.Errcase.subLoadFailed, "从数据库中查询 \(From.logName) 模型的 OptionalSub \(To.logName) 模型失败", metadata: ["from_id": .stringConvertible(self.fromId)], category: .internal)
            .flatMapThrowing
        { parents throws(DTO.Errcase.ErrType) in
            guard parents.count < 2 else {
                throw DTO.Errcase.optionalSuperLoadFailed.d("数据库中 \(From.logName) 模型的 OptionalSub \(To.logName) 存在不止一条关系", category: .internal).metadata(["optional_sub_ids": .data(parents.map { $0.id })])
            }
            
            self.lock.withLock {
                self.__loaded = true
                self.__value = parents.first
            }
            
            return parents.first
        }
    }
    
    func load(on db: PGDatabase) -> EventLoopRes<Void, DTO.Errcase> {
        get(on: db).map { _ in }
    }
}

extension OptionalSubProperty: DTO.Property {
    public static var logName: String { "OptionalSub<\(From.logName), \(To.logName)>" }
    
    package var value: To? {
        lock.withLock { __value }
    }
}

extension OptionalSubProperty: __Property {}
