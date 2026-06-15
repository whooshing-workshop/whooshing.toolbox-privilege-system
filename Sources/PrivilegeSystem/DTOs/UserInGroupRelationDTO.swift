import Fluent
import Foundation
import ErrorHandle
import PrivilegeModule
import DataConvertable
import LoggingAdvanced
import AnyCodable
import Policy
import ResourceMacros

public struct PUserInGroupRelation: DTO.Prepare {
    public typealias QueriedModel = QUserInGroupRelation
    public let id: UUID?
    public let user: QUser
    public let group: QGroup
    
    init(
        id: UUID? = nil,
        user: QUser,
        group: QGroup
    ) {
        self.id = id
        self.user = user
        self.group = group
    }
    
    public var maps: [CodingKeys: AnyCodable] {[
        .id: .init(self.id),
        .user: .init(user.json),
        .group: .init(group.json)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case user
        case group
    }
}

public struct QUserInGroupRelation: DTO.Queried {
    public typealias PrepareModel = PUserInGroupRelation
    public let id: UUID
    public let user: QUser
    public let group: QGroup
    public let createdAt: Date
    
    package let __m: __SDBM.UserGroupPivot?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \__SDBM.UserGroupPivot.$id
    
    public var maps: [CodingKeys: AnyCodable] {[
        .id: .init(self.id),
        .user: .init(self.user.json),
        .group: .init(self.group.json),
        .createdAt: .init(self.createdAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case user
        case group
        case createdAt = "created_at"
    }
    
    init(
        id: UUID,
        user: QUser,
        group: QGroup,
        createdAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.user = user
        self.group = group
        self.createdAt = createdAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.user = try container.decode(QUser.self, forKey: .user)
        self.group = try container.decode(QGroup.self, forKey: .group)
        self.createdAt = try container.decode(DateWrapper.self, forKey: .createdAt).date
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.user, forKey: .user)
        try container.encode(self.group, forKey: .group)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
    }
}

extension PUserInGroupRelation: __Prepare {}

extension QUserInGroupRelation: __Queried {
    public typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: __SDBM.UserGroupPivot) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInGroupDTOFailed, category: .internal) {
            try Self.init(
                id: model.requireID(),
                user: QUser.make(from: model.user).get(),
                group: QGroup.make(from: model.group).get(),
                createdAt: model.createdAt,
                model: model
            )
        }
    }
}

// MARK: - =|

infix operator =| : MappingPrecedence

public func =| (
    left: QUser,
    right: QGroup
) -> PUserInGroupRelation {
    .init(user: left, group: right)
}
