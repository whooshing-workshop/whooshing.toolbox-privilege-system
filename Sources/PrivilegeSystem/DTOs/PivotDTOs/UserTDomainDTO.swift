import Query
import PrivilegeModule
import Foundation
import Policy
import ErrorHandle
import PgSQL
import FluentKit

public struct UserTDomain: PivotDTO {
    public typealias Primary = QRole
    public typealias Secondary = QGroup
    
    public let id: UUID
    public let userId: UUID
    public let domainId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { userId }
    public var secondaryId: UUID { domainId }
    
    public static let logName: String = "UserTDomain"
    
    public typealias ErrorType = PrivilegeSystem.Errcase
    package typealias PivotT = __SDBM.Pivots.UserDomain
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
        \.userId: \SQLModel.$primaryModel.$id,
        \.domainId: \SQLModel.$secondaryModel.$id
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
        self.domainId = secondaryId
        self.createdAt = createdAt
        self.__m = model
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .userDomainDTOFailed
}

extension UserTDomain: __PivotDTO {}
