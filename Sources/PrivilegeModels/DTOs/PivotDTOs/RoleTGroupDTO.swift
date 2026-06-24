import Foundation
import PrivilegeModule

public struct RoleTGroup: DTO.Pivot {
    public typealias Primary = QRole
    public typealias Secondary = QGroup
    
    public let id: UUID
    public let roleId: UUID
    public let groupId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { roleId }
    public var secondaryId: UUID { groupId }
    
    public static let logName: String = "RoleTGroup"
    
    public typealias ErrorType = PrivilegeModuleExtended.Errcase
    package typealias PivotT = __SDBM.Pivots.RoleGroup
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
        \.id: \SQLModel.$id,
        \.roleId: \SQLModel.$primaryModel.$id,
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
        self.roleId = primaryId
        self.groupId = secondaryId
        self.createdAt = createdAt
        self.__m = model
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .roleGroupDTOFailed
}

extension RoleTGroup: __PivotDTO {}
