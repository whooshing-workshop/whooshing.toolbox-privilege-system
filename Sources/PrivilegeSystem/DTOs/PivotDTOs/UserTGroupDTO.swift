import Query
import PrivilegeModule
import Foundation
import Policy
import ErrorHandle
import PgSQL
import FluentKit

public struct UserTGroup: PivotDTO {
    public typealias Primary = QRole
    public typealias Secondary = QGroup
    
    public let id: UUID
    public let userId: UUID
    public let groupId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { userId }
    public var secondaryId: UUID { groupId }
    
    public static let logName: String = "UserTGroup"
    
    public typealias ErrorType = PrivilegeSystem.Errcase
    package typealias PivotT = __SDBM.Pivots.UserGroup
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
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
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .userGroupDTOFailed
}

extension UserTGroup: __PivotDTO {}
