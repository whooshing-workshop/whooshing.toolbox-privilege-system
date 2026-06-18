import PgSQL
import Fluent
import DTOBuilder

public extension __SDBM {
    typealias DomainGroupPivot = Pivot<Pivots.DomainGroup>
}

public extension __SDBM.Pivots {
    struct DomainGroup: PivotType {
        public typealias PrimaryModel = __SDBM.Domain
        public typealias SecondaryModel = __SDBM.Group
        
        public static let foreignPrimaryName = "domain"
        public static let foreignSecondaryName = "group"
        
        public static let foreignPrimaryType = DatabaseSchema.DataType.uuid
    }
}
