import PgSQL
import Policy
import Fluent

extension __SDBM {
    typealias DomainGroupPivot = Pivot<Pivots.DomainGroup>
}

extension __SDBM.Pivots {
    struct DomainGroup: PivotType {
        typealias PrimaryModel = __SDBM.Domain
        typealias SecondaryModel = __SDBM.Group
        
        static let foreignPrimaryName = "domain"
        static let foreignSecondaryName = "group"
        
        static let foreignPrimaryType = DatabaseSchema.DataType.uuid
    }
}
