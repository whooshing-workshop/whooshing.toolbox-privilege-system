import Foundation
import Query

public extension DTO.DBModel {
    typealias Subs<To> = SubsProperty<Self, To>
        where To: DTO.DBModel
}

// 需要隐式传递模型的 id 主键值
// self.$<subs>.fromId == XXX
@propertyWrapper
final public class SubsProperty<From, To>: @unchecked Sendable
    where
        From: DTO.DBModel,
        To: DTO.DBModel
{
    public var projectedValue: SubsProperty<From, To> { self }
    
    public var wrappedValue: [To] {
        lock.withLock {
            guard loaded else {
                fatalError("Subs 未加载，请调用 $ 前缀后调用 load(on:) 函数后再取得加载后的内容")
            }
            
            return __values!
        }
    }
    
    public var loaded: Bool { __values != nil }
    
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
    
    enum ParentKeyPath {
        case required(KeyPath<To, To.Super<From>>)
        case optional(KeyPath<To, To.OptionalSuper<From>>)
    }
    
    let parentKeyPath: ParentKeyPath
    
    private var __values: [To]? = nil
    private var __fromId: UUID? = nil           // 模型本体的 id 主键
    private let lock = NIOLock()
    
    public init(for parentKey: KeyPath<To, To.Super<From>>) {
        self.parentKeyPath = .required(parentKey)
    }
    
    public init(for parentKey: KeyPath<To, To.OptionalSuper<From>>) {
        self.parentKeyPath = .optional(parentKey)
    }
    
    public func inject(_ value: [To]) {
        lock.withLock {
            __values = value
        }
    }
    
    public func get(on transactor: Transactor) -> EventLoopRes<[To], DTO.Errcase> {
        self.get(on: transactor.db)
    }
    
    public func load(on transactor: Transactor) -> EventLoopRes<Void, DTO.Errcase> {
        self.load(on: transactor.db)
    }
}

package extension SubsProperty {
    func get(on db: PGDatabase) -> EventLoopRes<[To], DTO.Errcase> {
        let builder = switch parentKeyPath {
        case .required(let keyPath):
            To.query(on: db).filter(keyPath.appending(path: \.id) == self.fromId)
        case .optional(let keyPath):
            To.query(on: db).filter(keyPath.appending(path: \.id) == self.fromId)
        }
        
        return builder.all()
            .errCast(DTO.Errcase.subsLoadFailed, "从数据库中查询 \(From.logName) 模型的 Subs \(To.logName) 模型失败", metadata: ["from_id": .stringConvertible(self.fromId)], category: .internal)
            .flatMapThrowing
        { childs throws(DTO.Errcase.ErrType) in
            self.lock.withLock {
                self.__values = childs
            }
            
            return childs
        }
    }
    
    func load(on db: PGDatabase) -> EventLoopRes<Void, DTO.Errcase> {
        get(on: db).map { _ in }
    }
}

extension SubsProperty: DTO.Property {
    public static var logName: String { "Subs<\(From.logName), \(To.logName)>" }
    
    package var value: [To]? {
        lock.withLock { __values }
    }
}

extension SubsProperty: __Property {}
