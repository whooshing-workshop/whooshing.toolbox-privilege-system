import Query
import PrivilegeModule
import Foundation
import ErrorHandle
import PgSQL
import FluentKit
import DTOBuilder

public struct RoleTUserInGroup: DTO.Pivot {
    public typealias Primary = QRole
    public typealias Secondary = UserTGroup
    
    public let id: UUID
    public let roleId: UUID
    public let userInGroupId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { roleId }
    public var secondaryId: UUID { userInGroupId }
    
    public static let logName: String = "RoleTUserInGroup"
    
    public typealias ErrorType = PrivilegeSystem.Errcase
    package typealias PivotT = __SDBM.Pivots.RoleUserInGroup
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
        \.id: \SQLModel.$id,
        \.roleId: \SQLModel.$primaryModel.$id,
        \.userInGroupId: \SQLModel.$secondaryModel.$id
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
        self.userInGroupId = secondaryId
        self.createdAt = createdAt
        self.__m = model
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .roleUserInGroupDTOFailed
}

extension RoleTUserInGroup: __PivotDTO {}
