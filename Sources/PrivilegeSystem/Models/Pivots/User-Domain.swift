import PgSQL
import Policy
import Fluent

typealias UserDomainPivot = Pivot<Pivots.UserDomain>

extension Pivots {
    struct UserDomain: PivotType {
        typealias PrimaryModel = User
        typealias SecondaryModel = Domain
        
        static let foreignPrimaryName = "user"
        static let foreignSecondaryName = "domain"
        
        static let foreignSecondaryType = DatabaseSchema.DataType.int64
    }
}
