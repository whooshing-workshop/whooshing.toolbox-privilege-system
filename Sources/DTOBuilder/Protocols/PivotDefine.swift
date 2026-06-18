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

public extension DTO {
    
    enum PivotCodingKeys: String, DTO.CodingKey {
        case id
        case primaryId = "primary_id"
        case secondaryId = "secondary_id"
        case createdAt = "create_at"
        case role // 这是为了 PUserTGroup 单独设置的，其他类型均不需要
    }
    
    protocol Pivot: DTO.Model, Query.Queriable where CodingKeys == PivotCodingKeys {
        associatedtype Primary: DTO.Model
        associatedtype Secondary: DTO.Model
        var id: UUID { get }
        var primaryId: UUID { get }
        var secondaryId: UUID { get }
        var createdAt: Date { get }
    }
}

public extension DTO.Pivot {
    var summaryKeys: [CodingKeys] { [.id, .primaryId, .createdAt] }
    
    var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .primaryId: .init(obj: self.primaryId),
        .secondaryId: .init(obj: self.secondaryId),
        .createdAt: .init(obj: self.createdAt)
    ]}
}

package protocol __PivotDTO: DTO.Pivot, __DBModel
    where
        SQLModel == Pivot<PivotT>,
        Failure.ErrType == BscError<Failure>,
        Model == SQLModel,
        ErrorType == Failure
{
    associatedtype PivotT: PivotType
    associatedtype Failure: ErrList
    
    static var errorThrows: Failure { get }
    
    static var aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] { get }
    
    init(
        id: UUID,
        primaryId: UUID,
        secondaryId: UUID,
        createdAt: Date,
        model: SQLModel?
    )
}

 extension __PivotDTO {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self = try Self.init(
            id: container.decode(UUID.self, forKey: .id),
            primaryId: container.decode(UUID.self, forKey: .primaryId),
            secondaryId: container.decode(UUID.self, forKey: .secondaryId),
            createdAt: container.decode(DateWrapper.self, forKey: .createdAt).date,
            model: nil
        )
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(primaryId, forKey: .primaryId)
        try container.encode(secondaryId, forKey: .secondaryId)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
    }
}

extension __PivotDTO {
    package static var idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> { \.$id }
    
    public static func make(from model: SQLModel) -> Res<Self, Failure> {
        .init(throws: errorThrows, category: .internal) {
            try Self.init(
                id: model.requireID(),
                primaryId: model.$primaryModel.id,
                secondaryId: model.$secondaryModel.id,
                createdAt: model.createdAt,
                model: model
            )
        }
    }
}

extension __PivotDTO {
    public static var paths: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] {
        var binds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
            \Self.id: \SQLModel.$id,
            \Self.primaryId: \SQLModel.$primaryModel.$id,
            \Self.secondaryId: \SQLModel.$secondaryModel.$id,
            \Self.createdAt: \SQLModel.createdAt
        ]
        
        for (k, v) in aliasKeyBinds {
            binds[k] = v
        }
        
        return binds
    }
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> {
        builder
            .field(Model.self, \.$id)
            .field(Model.self, \.$primaryModel.$id)
            .field(Model.self, \.$secondaryModel.$id)
            .field(Model.self, \.$createdAt)
    }
}

extension PartialKeyPath: @retroactive @unchecked Sendable {}
