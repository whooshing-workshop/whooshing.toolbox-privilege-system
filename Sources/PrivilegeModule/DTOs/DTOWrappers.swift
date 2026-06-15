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

public enum DTO {
    public enum Errcase: String, ErrList {
        case modelQueryFailed = "数据库查询模型失败"
        case modelNotExist = "数据库模型不存在"
    }
}

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
        Codable,
        Sendable,
        Equatable,
        Hashable,
        Loggerable,
        CustomStringConvertible
    {
        associatedtype CodingKeys: CodingKey
        // 用于比较和打印，不用与编解码
        var maps: [CodingKeys: AnyCodable] { get }
    }
    
    protocol Prepare: Model {
        associatedtype QueriedModel: Queried
        var id: UUID? { get }
    }
    
    protocol Queried: Model {
        associatedtype PrepareModel: Prepare
        var id: UUID { get }
    }
}

package protocol __Prepare: DTO.Prepare
where
    SQLModel.IDValue == UUID,
    QueriedModel: __Queried,
    QueriedModel.SQLModel == SQLModel
{
    associatedtype SQLModel: PGModel
}

package protocol __Queried: DTO.Queried
where
    SQLModel.IDValue == UUID,
    PrepareModel: __Prepare,
    PrepareModel.SQLModel == SQLModel
{
    associatedtype Failure: ErrList
    associatedtype SQLModel: PGModel
    var __m: SQLModel? { get }
    static var idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> { get }
    static func make(from model: SQLModel) -> Res<Self, Failure>
}

public extension DTO.Model {
    var description: String { formatJson(json) }
    
    var json: [String: AnyCodable] {
        var j: [String: AnyCodable] = [:]
        for (k, v) in maps {
            j[k.rawValue] = .init(v)
        }
        return j
    }
    
    func hash(into hasher: inout Hasher) {
        for (_, v) in json {
            hasher.combine(v)
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.maps == rhs.maps
    }
}

public extension DTO.Prepare {
    func like(_ rhs: QueriedModel) -> Bool {
        for (k, v) in maps {
            guard
                let key = QueriedModel.CodingKeys(stringValue: k.stringValue),
                rhs.maps[key] == v
            else { return false }
        }
        return true
    }
}

public extension DTO.Queried {
    func like(_ rhs: PrepareModel) -> Bool {
        // 以 PrepareModel 为基准来做比较，而非 Self
        for (k, v) in rhs.maps {
            guard
                let key = CodingKeys(stringValue: k.stringValue),
                maps[key] == v
            else { return false }
        }
        return true
    }
}

public extension Collection where Element: DTO.Prepare {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.QueriedModel {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element: DTO.Queried {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.PrepareModel {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

package extension __Queried {
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
