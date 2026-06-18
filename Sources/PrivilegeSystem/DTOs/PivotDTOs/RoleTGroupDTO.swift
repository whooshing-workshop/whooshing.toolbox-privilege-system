import Query
import PrivilegeModule
import Foundation
import ErrorHandle
import PgSQL
import FluentKit
import DTOBuilder

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
    
    public typealias ErrorType = PrivilegeSystem.Errcase
    package typealias PivotT = __SDBM.Pivots.RoleGroup
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
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
