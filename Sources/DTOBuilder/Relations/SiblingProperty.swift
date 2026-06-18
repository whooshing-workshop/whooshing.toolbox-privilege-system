import Foundation
import NIOAdvanced
import ErrorHandle
import NIOConcurrencyHelpers
import Query

public extension DTO.DBModel {
    typealias Sibling<To, Through> = SiblingProperty<Self, To, Through>
        where Through: DTO.Pivot, To: DTO.DBModel
}

// 需要隐式传递模型的 id 主键值
// self.$<sibling>.fromId == XXX
@propertyWrapper
final public class SiblingProperty<From, To, Through>: @unchecked Sendable
    where
        From: DTO.DBModel,
        To: DTO.DBModel,
        Through: DTO.Pivot
{
    public var projectedValue: SiblingProperty<From, To, Through> { self }
    
    public var wrappedValue: [To] {
        lock.withLock {
            guard loaded else {
                fatalError("\(Self.logName) 未加载，请调用 $ 前缀后调用 load(on:) 函数后再取得加载后的内容")
            }
            
            return __values!
        }
    }
    
    public var ids: [UUID] {
        lock.withLock {
            guard idsLoaded else {
                fatalError("Sibling 未加载，请调用 $ 前缀后调用 load(on:) 函数后再取得加载后的内容")
            }
            
            return __ids!
        }
    }
    
    public var loaded: Bool { __values != nil }
    public var idsLoaded: Bool { __ids != nil }
    
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
    
    let fromKeyPath: KeyPath<Through, UUID>
    let toKeyPath: KeyPath<Through, UUID>
    
    private var __values: [To]? = nil
    private var __ids: [UUID]? = nil
    private var __fromId: UUID? = nil
    private let lock = NIOLock()
    
    public init(
        through: Through.Type,
        from: KeyPath<Through, UUID>,
        to: KeyPath<Through, UUID>
    ) {
        self.fromKeyPath = from
        self.toKeyPath = to
    }
    
    public func getIdsOnly(on system: Query.System) -> EventLoopRes<[UUID], DTO.Errcase> {
        Through.query(on: system)
            .filter(self.fromKeyPath == fromId)
            .all()
            .errCast(DTO.Errcase.siblingsLoadFailed, "从数据库中查询中间表 \(Through.logName) 失败", metadata: ["from_id": .stringConvertible(self.fromId)], category: .internal)
            .flatMapThrowing
        { siblings throws(DTO.Errcase.ErrType) in
            let ids = siblings.map { $0[keyPath: self.toKeyPath] }
            
            self.lock.withLock {
                self.__ids = ids
                self.__values = nil
            }
            
            return ids
        }.flatMapErrorThrowing { error throws(DTO.Errcase.ErrType) in
            self.lock.withLock {
                self.__ids = nil
                self.__values = nil
            }
            
            throw error
        }
    }
    
    public func get(on system: Query.System) -> EventLoopRes<[To], DTO.Errcase> {
        getIdsOnly(on: system).flatMap { ids in
            To.query(on: system)
                .filter(\.id ~~ ids)
                .all()
                .errCast(DTO.Errcase.siblingsLoadFailed, "从数据库中通过中间表 \(Through.logName) 查询 \(To.logName) 模型失败", metadata: ["from_id": .stringConvertible(self.fromId)], category: .internal)
        }.map { res in
            self.lock.withLock {
                self.__values = res
            }
            
            return res
        }.flatMapErrorThrowing { error throws(DTO.Errcase.ErrType) in
            self.lock.withLock {
                self.__ids = nil
                self.__values = nil
            }
            
            throw error
        }
    }
    
    public func loadIdsOnly(on system: Query.System) -> EventLoopRes<Void, DTO.Errcase> {
        getIdsOnly(on: system).map { _ in }
    }
    
    public func load(on system: Query.System) -> EventLoopRes<Void, DTO.Errcase> {
        get(on: system).map { _ in }
    }
}

extension SiblingProperty: DTO.Property {
    public var maps: [DTO.PropertyCodingKeys : AnyHashable?] {
        lock.withLock {[
            .loaded: .init(obj: loaded),
            .value: .init(obj: __values),
            .idsLoaded: .init(obj: idsLoaded),
            .ids: .init(obj: __ids)
        ]}
    }
    
    public static var logName: String { "Sibling<\(From.logName), \(To.logName)>" }
}

extension SiblingProperty: __Property {
    // 仅为占位符，为了符合 __Property 协议
    package typealias Value = String
}
