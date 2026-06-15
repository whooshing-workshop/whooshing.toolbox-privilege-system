import PgSQL
import Policy
import Fluent

extension __SDBM {
    typealias UserDomainPivot = Pivot<Pivots.UserDomain>
}

extension __SDBM.Pivots {
    struct UserDomain: PivotType {
        typealias PrimaryModel = __SDBM.User
        typealias SecondaryModel = __SDBM.Domain
        
        static let foreignPrimaryName = "user"
        static let foreignSecondaryName = "domain"
        
        static let foreignSecondaryType = DatabaseSchema.DataType.uuid
    }
}
