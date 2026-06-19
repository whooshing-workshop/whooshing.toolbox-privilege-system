import Foundation
import Fluent
import PgSQL
import Collections
import NIOAdvanced
import ErrorHandle
import LoggingAdvanced
import NIOConcurrencyHelpers
import Query
@preconcurrency import AnyCodable

//          Public Protocols            |                      Package Protocols                   |
//                                      |                                                          |
//              DTO.Model               |                     __Model: DTO.Model                   |
//             /        \               |                      /               \                   |
//            /          \              |                     /                 \                  |
//           /            \             |                    /                   \                 |
//          /              \            |                   /                     \                |
//     DTO.Prepare     DTO.DBModel      |     __Prepare: DTO.Prepare    __DBModel: DTO.DBModel     |
//                          |           |                                          |               |
//                          |           |                                          |               |
//                          |           |                                          |               |
//                          |           |                                          |               |
//                     DTO.Queried      |                               __Queried: DTO.Queried     |
//                                      |                                                          |
//
// DTO.Model 继承各种基本协议 Encodable, Sendable, Equatable, Hashable, Loggerable, CustomStringConvertible，且提供默认实现
// __Model 为 DTO.Model 实现私有默认实现
//
// DTO.Prepare 为未存入数据库前的数据的协议，提供了默认实现
// __Prepare 为 DTO.Prepare 实现私有默认实现
//
// DTO.DBModel 实现该协议的数据结构，均与数据库相关，可直接做为数据库模型的等比模型，且提供了默认实现
// __DBModel 为 DTO.DBModel 实现私有默认实现
//
// DTO.Queried 为数据库查询或创建 Returning 的数据结构协议，且提供了默认实现
// __Queried 为 DTO.Queried 实现私有默认实现

public enum DTO {}

public typealias CK = CodingKey

public extension DTO {
    protocol CodingKey:
        CK,
        Sendable,
        CaseIterable,
        Hashable,
        RawRepresentable
    where RawValue == String {}
    
    protocol Model:
        Sendable,
        Encodable,
        Equatable,
        Hashable,
        Loggerable,
        CustomStringConvertible
    {
        associatedtype CodingKeys: CodingKey
        // 用于比较和打印，不用与编解码
        static var logName: String { get }
        var maps: [CodingKeys: AnyHashable?] { get }
        var summaryKeys: [CodingKeys] { get }
    }
    
    protocol Prepare: Model, Codable {
        associatedtype QueriedModel: Queried
        var id: UUID? { get }
    }
    
    protocol DBModel: Model, Query.Queriable, Codable {
        var id: UUID { get }
        static var idKey: KeyPath<Self, UUID> { get }  // 这个属性是因为 swift keypath 判断机制，\DBModel.id != \<Model which implement DBModel>.id，使用该实例可以确保 KeyPath 比较正确
        static func make(from ids: [UUID], on system: Query.System) -> EventLoopRes<[Self], DTO.Errcase>
    }
    
    protocol Queried: DBModel {
        associatedtype PrepareModel: Prepare
    }
}

package protocol __Model: DTO.Model
where
    SQLModel.IDValue == UUID
{
    associatedtype SQLModel: PGModel
    var id: UUID { get }
    var __m: SQLModel? { get }
    static var idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> { get }
}

package protocol __Prepare: DTO.Prepare
where
    SQLModel.IDValue == UUID,
    QueriedModel: __Queried,
    QueriedModel.SQLModel == SQLModel
{
    associatedtype SQLModel: PGModel
}

package protocol __DBModel: __Model, DTO.DBModel {}

package protocol __Queried: __DBModel, DTO.Queried
where
    PrepareModel: __Prepare,
    PrepareModel.SQLModel == SQLModel
{
    associatedtype Failure: ErrList
    static func make(from model: SQLModel) -> Res<Self, Failure>
}

public extension DTO.Model {
    var description: String { formatJson(json.mapValues { .init($0) }) }
    
    var summaryDescription: String {
        let m = self.maps
        var res = Self.logName + "("
        
        res += self.summaryKeys.compactMap { m[$0]! == nil ? nil : ($0.rawValue, m[$0]!!) }.map { key, value in
            if let loggerable = value.base as? Loggerable {
                return "\(key): \(loggerable.summaryDescription)"
            } else {
                return "\(key): \(value.description)"
            }
        }.joined(by: ", ")
        
        res += ")"
        
        return res
    }
    
    var json: [String: AnyHashable?] {
        var j: [String: AnyHashable?] = [:]
        for (k, v) in maps {
            j[k.rawValue] = v
        }
        return j
    }
    
    func hash(into hasher: inout Hasher) {
        let m = self.maps
        for key in CodingKeys.allCases {
            hasher.combine(m[key] ?? nil)
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.maps == rhs.maps
    }
}

public extension DTO.DBModel {
    static var idKey: KeyPath<Self, UUID> { \.id }
}

public extension DTO.Prepare {
    func hash(into hasher: inout Hasher) {
        let m = self.maps
        for key in CodingKeys.allCases {
            if key.rawValue == "id" { continue }
            hasher.combine(m[key] ?? nil)
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        let lmaps = lhs.maps
        let rmaps = rhs.maps
        for (k, v) in lmaps {
            if k.rawValue == "id" { continue }
            guard v == rmaps[k] else { return false }
        }
        guard
            let lid = lmaps[.init(rawValue: "id")!]!,
            let rid = rmaps[.init(rawValue: "id")!]!
        else { return true }
        
        return lid == rid
    }
    
    func like(_ rhs: QueriedModel) -> Bool {
        let ljson = self.json
        let rjson = rhs.json
        for (k, v) in ljson {
            if k == "id" { continue }
            guard rjson[k] == v else { return false }
        }
        guard let lid = ljson["id"]! else { return true }
        
        return lid == rjson["id"]!
    }
}

public extension DTO.Queried where Self == PrepareModel.QueriedModel {
    func like(_ rhs: PrepareModel) -> Bool {
        // 以 PrepareModel 为基准来做比较，而非 Self
        rhs.like(self)
    }
}

public extension Collection where Element: DTO.Prepare {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.QueriedModel {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element: DTO.Queried, Element == Element.PrepareModel.QueriedModel {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.PrepareModel {
        self.elementsEqual(rhs, by: { $1.like($0) })
    }
}

public extension DTO.DBModel {
    static func make(from ids: [UUID], on system: Query.System) -> EventLoopRes<[Self], DTO.Errcase> {
        Self.query(on: system)
            .filter(\.id ~~ ids)
            .all()
            .errCast(DTO.Errcase.modelQueryFailed, "从数据库中根据 id 查询 \(Self.logName) 模型失败", category: .internal)
    }
}

package extension __Model {
    func model(from db: PGDatabase) -> EventLoopRes<SQLModel, DTO.Errcase> {
        guard let m = __m else {
            return SQLModel.query(on: db)
                .filter(Self.idProperty == id)
                .first()
                .withError(DTO.Errcase.modelQueryFailed, category: .internal)
                .flatMap
            { res in
                guard let r = res else {
                    return db.eventLoop.makeFailedResult(DTO.Errcase.modelNotExist.d(category: .external))
                }
                return db.eventLoop.makeSucceededResult(r)
            }
        }
        return db.eventLoop.makeSucceededResult(m)
    }
}

// MARK: - DTOUpdater

package protocol DTOUpdater: Sendable, Loggerable {
    associatedtype QueriedDTO: Sendable
    associatedtype DBModel: PGModel & Sendable
    associatedtype CodingKeysPathType: AnyKeyPath
    var id: UUID { get }
    var updates: OrderedDictionary<
        CodingKeysPathType,
        (QueryBuilder<DBModel>, QueriedDTO?) throws -> QueryBuilder<DBModel>
    > { get }
    var needsPeek: Bool { get }
    init(
        id: UUID,
        updates: OrderedDictionary<
            CodingKeysPathType,
            (QueryBuilder<DBModel>, QueriedDTO?) throws -> QueryBuilder<DBModel>
        >,
        needsPeek: Bool
    )
}

package extension DTOUpdater {
    var all: [CodingKeysPathType] { .init(updates.keys) }
    
    func generate(
        needsPeek: Bool = false,
        key: CodingKeysPathType,
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

extension DTOUpdater {
    public var logDescription: String {
        return formatJson([
            "target_id": AnyCodable(id.shortString),
            "updated_fields": AnyCodable(updates.keys.map { String(describing: $0) })
        ])
    }
    public var description: String { logDescription }
    public var summaryDescription: String { "Updater(\(id.shortString), updates: \(updates.keys.count))" }
}
