import Query
import Foundation
import Policy
import ErrorHandle
import PgSQL
import FluentKit
import ResourceMacros
import DTOBuilder

public extension PM {
    struct PrivilegeTAnyResource: DTO.Pivot {
        public typealias Primary = QPrivilege
        public typealias Secondary = AnyResource
        
        public let id: UUID
        public let privilegeId: UUID
        public let resourceId: UUID
        public let createdAt: Date
        
        public var primaryId: UUID { privilegeId }
        public var secondaryId: UUID { resourceId }
        
        public static var logName: String { "PrivilegeTAnyResource" }
        
        public typealias S = PM<ResourceList>
        public typealias ErrorType = S.Errcase
        package typealias PivotT = S.__DBM.PrivilegeAnyResource
        
        package static var aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] {[
            \.privilegeId: \SQLModel.$primaryModel.$id,
            \.resourceId: \SQLModel.$secondaryModel.$id
        ]}
        
        package init(
            id: UUID,
            primaryId: UUID,
            secondaryId: UUID,
            createdAt: Date,
            model: SQLModel?
        ) {
            self.id = id
            self.privilegeId = primaryId
            self.resourceId = secondaryId
            self.createdAt = createdAt
            self.__m = model
        }
        
        package let __m: Pivot<PivotT>?
        package static var errorThrows: Failure { .privilegeAnyResourceDTOFailed }
    }
}

extension PM.PrivilegeTAnyResource: __PivotDTO {}

public extension PM {
    struct PrivilegeTResource<G: Resource>: DTO.Pivot where G.ResourceType == ResourceList {
        public typealias Primary = QPrivilege
        public typealias Secondary = QResource<G>
        
        public let id: UUID
        public let privilegeId: UUID
        public let resourceId: UUID
        public let createdAt: Date
        
        public var primaryId: UUID { privilegeId }
        public var secondaryId: UUID { resourceId }
        
        public static var logName: String { "PrivilegeTResource" }
        
        public typealias S = PM<ResourceList>
        public typealias ErrorType = S.Errcase
        package typealias PivotT = S.__DBM.PrivilegeResource<G>
        
        package static var aliasKeyBinds: [PartialKeyPath<Self> : PartialKeyPath<SQLModel>] {[
            \.id: \SQLModel.$id,
            \.privilegeId: \SQLModel.$primaryModel.$id,
            \.resourceId: \SQLModel.$secondaryModel.$id
        ]}
        
        package init(
            id: UUID,
            primaryId: UUID,
            secondaryId: UUID,
            createdAt: Date,
            model: SQLModel?
        ) {
            self.id = id
            self.privilegeId = primaryId
            self.resourceId = secondaryId
            self.createdAt = createdAt
            self.__m = model
        }
        
        package let __m: Pivot<PivotT>?
        package static var errorThrows: Failure { .privilegeResourceDTOFailed }
    }
}

extension PM.PrivilegeTResource: __PivotDTO {}
