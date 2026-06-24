import Foundation
import PrivilegeModule

public struct DomainTGroup: DTO.Pivot {
    public typealias Primary = QDomain
    public typealias Secondary = QGroup
    
    public let id: UUID
    public let domainId: UUID
    public let groupId: UUID
    public let createdAt: Date
    
    public var primaryId: UUID { domainId }
    public var secondaryId: UUID { groupId }
    
    public static let logName: String = "DomainTGroup"
    
    public typealias ErrorType = PrivilegeModuleExtended.Errcase
    package typealias PivotT = __SDBM.Pivots.DomainGroup
    
    package static let aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] = [
        \.id: \SQLModel.$id,
        \.domainId: \SQLModel.$primaryModel.$id,
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
        self.domainId = primaryId
        self.groupId = secondaryId
        self.createdAt = createdAt
        self.__m = model
    }
    
    package let __m: Pivot<PivotT>?
    package static let errorThrows: Failure = .domainGroupDTOFailed
}

extension DomainTGroup: __PivotDTO {}
