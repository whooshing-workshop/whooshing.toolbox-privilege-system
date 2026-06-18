import Foundation
import NIOAdvanced
import ErrorHandle
import NIOConcurrencyHelpers
import Query

public extension DTO.DBModel {
    typealias Sub<To> = SubProperty<Self, To>
        where To: DTO.DBModel
}

// 需要隐式传递模型的 id 主键值
// self.$<sub>.fromId == XXX
@propertyWrapper
final public class SubProperty<From, To>: @unchecked Sendable
    where
        From: DTO.DBModel,
        To: DTO.DBModel
{
    public var projectedValue: SubProperty<From, To> { self }
    
    public var wrappedValue: To {
        lock.withLock {
            guard loaded else {
                fatalError("\(Self.logName) 未加载，请调用 $ 前缀后调用 load(on:) 函数后再取得加载后的内容")
            }
            
            return __value!
        }
    }
    
    public var loaded: Bool { __value != nil }
    
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
    
    private var __value: To? = nil
    private var __fromId: UUID? = nil           // 模型本体的 id 主键
    private let lock = NIOLock()
    
    public init(
        for parentKey: KeyPath<To, To.Super<From>>
    ) {
        self.parentKeyPath = parentKey
    }
    
    public func get(on system: Query.System) -> EventLoopRes<To, DTO.Errcase> {
        To.query(on: system)
            .filter(parentKeyPath.appending(path: \.id) == self.fromId)
            .all()
            .errCast(DTO.Errcase.subLoadFailed, "从数据库中查询 \(From.logName) 模型的 Sub \(To.logName) 模型失败", metadata: ["from_id": .stringConvertible(self.fromId)], category: .internal)
            .flatMapThrowing
        { parents throws(DTO.Errcase.ErrType) in
            guard parents.count < 2 else {
                throw DTO.Errcase.optionalSuperLoadFailed.d("数据库中 \(From.logName) 模型的 Sub \(To.logName) 存在不止一条关系", category: .internal).metadata(["optional_sub_ids": .data(parents.map { $0.id })])
            }
            
            guard let p = parents.first else {
                throw DTO.Errcase.subLoadFailed.d("数据库中 \(From.logName) 模型的 Sub \(To.logName) 不存在", category: .internal).metadata(["from_id": .stringConvertible(self.fromId)])
            }
            
            self.lock.withLock {
                self.__value = p
            }
            
            return p
        }
    }
    
    public func load(on system: Query.System) -> EventLoopRes<Void, DTO.Errcase> {
        get(on: system).map { _ in }
    }
}

extension SubProperty: DTO.Property {
    public static var logName: String { "Sub<\(From.logName), \(To.logName)>" }
    
    package var value: To? {
        lock.withLock { __value }
    }
}

extension SubProperty: __Property {}
