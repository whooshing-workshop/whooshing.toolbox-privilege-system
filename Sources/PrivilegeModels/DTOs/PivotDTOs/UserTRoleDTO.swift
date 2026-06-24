import Foundation
import PrivilegeModule

public struct UserTRole: DTO.Pivot {
    public typealias Primary = QUser
    public typealias Secondary = QRole
    
    public let id: UUID
    public let userId: UUID
    public let roleId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { userId }
    public var secondaryId: UUID { roleId }
    
    public static let logName: String = "UserTRole"
    
    public typealias ErrorType = PrivilegeModuleExtended.Errcase
    package typealias PivotT = __SDBM.Pivots.UserRole
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
        \.id: \SQLModel.$id,
        \.userId: \SQLModel.$primaryModel.$id,
        \.roleId: \SQLModel.$secondaryModel.$id
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
        self.roleId = secondaryId
        self.createdAt = createdAt
        self.__m = model
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .userRoleDTOFailed
}

extension UserTRole: __PivotDTO {}
