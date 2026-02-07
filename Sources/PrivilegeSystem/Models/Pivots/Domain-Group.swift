import PgSQL
import Policy
import Fluent

typealias DomainGroupPivot = Pivot<Pivots.DomainGroup>

extension Pivots {
    struct DomainGroup: PivotType {
        typealias PrimaryModel = Domain
        typealias SecondaryModel = UGroup
        
        static let foreignPrimaryName = "domain"
        static let foreignSecondaryName = "group"
        
        static let foreignPrimaryType = DatabaseSchema.DataType.int64
    }
}
