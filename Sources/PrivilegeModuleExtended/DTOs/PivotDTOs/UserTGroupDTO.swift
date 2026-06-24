import Foundation
import PrivilegeModule

public struct PUserTGroup: DTO.Prepare {
    public typealias QueriedModel = UserTGroup
    public let id: UUID?
    public let primaryId: UUID
    public let secondaryId: UUID
    
    public var userId: UUID { primaryId }
    public var groupId: UUID { secondaryId }
    
    public static let logName: String = "PUserTGroup"
    
    public init(
        id: UUID? = nil,
        userId: UUID,
        groupId: UUID
    ) {
        self.id = id
        self.primaryId = userId
        self.secondaryId = groupId
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .primaryId: .init(obj: self.userId),
        .secondaryId: .init(obj: self.groupId)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.id, .primaryId, .secondaryId] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case primaryId = "primary_id"
        case secondaryId = "secondary_id"
    }
}

public struct UserTGroup: DTO.Pivot, DTO.Queried {
    public typealias PrepareModel = PUserTGroup
    
    public typealias Primary = QUser
    public typealias Secondary = QGroup
    
    public let id: UUID
    public let userId: UUID
    public let groupId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { userId }
    public var secondaryId: UUID { groupId }
    
    @Sibling(
        through: RoleTUserInGroup.self,
        from: \.userInGroupId,
        to: \.roleId
    )                                   public var roles: [QRole]
    
    public static let logName: String = "UserTGroup"
    
    public typealias ErrorType = PrivilegeModuleExtended.Errcase
    package typealias PivotT = __SDBM.Pivots.UserGroup
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
        \.id: \SQLModel.$id,
        \.userId: \SQLModel.$primaryModel.$id,
        \.groupId: \SQLModel.$secondaryModel.$id
    ]
    
    package init(
        id: UUID,
        primaryId: UUID,
        secondaryId: UUID,
        createdAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.userId = primaryId
        self.groupId = secondaryId
        self.createdAt = createdAt
        self.__m = model
        
        self.$roles.fromId = id
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .userGroupDTOFailed
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .primaryId: .init(obj: self.primaryId),
        .secondaryId: .init(obj: self.secondaryId),
        .createdAt: .init(obj: self.createdAt),
        
        .roles: .init(obj: self.$roles)
    ]}
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self = try Self.init(
            id: container.decode(UUID.self, forKey: .id),
            primaryId: container.decode(UUID.self, forKey: .primaryId),
            secondaryId: container.decode(UUID.self, forKey: .secondaryId),
            createdAt: container.decode(DateWrapper.self, forKey: .createdAt).date,
            model: nil
        )
        
        try self.$roles.inject(from: container.nestedContainer(keyedBy: DTO.PropertyCodingKeys.self, forKey: .roles))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(primaryId, forKey: .primaryId)
        try container.encode(secondaryId, forKey: .secondaryId)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
        
        try container.encode(self.$roles, forKey: .roles)
    }
}

extension PUserTGroup: __Prepare {}

extension UserTGroup: __PivotDTO, __Queried {}
