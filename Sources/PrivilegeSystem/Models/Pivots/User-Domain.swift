import PgSQL
import Policy
import Fluent

public extension __SDBM {
    typealias UserDomainPivot = Pivot<Pivots.UserDomain>
}

public extension __SDBM.Pivots {
    struct UserDomain: PivotType {
        public typealias PrimaryModel = __SDBM.User
        public typealias SecondaryModel = __SDBM.Domain
        
        public static let foreignPrimaryName = "user"
        public static let foreignSecondaryName = "domain"
        
        public static let foreignSecondaryType = DatabaseSchema.DataType.uuid
    }
}
