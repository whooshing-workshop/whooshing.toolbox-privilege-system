import PgSQL
import Censor

typealias DomainGroupPivot = Pivot<Pivots.DomainGroup>

extension Pivots {
    struct DomainGroup: PivotType {
        typealias PrimaryModel = Domain
        typealias SecondaryModel = UGroup
        
        static let foreignPrimaryName = "domain"
        static let foreignSecondaryName = "group"
    }
}
