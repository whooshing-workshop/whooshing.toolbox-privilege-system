import DTOBuilder

public extension __SDBM {
    typealias UserGroupPivot = Pivot<Pivots.UserGroup>
}

public extension __SDBM.Pivots {
    struct UserGroup: PivotType {
        public typealias PrimaryModel = __SDBM.User
        public typealias SecondaryModel = __SDBM.Group
        
        public static let foreignPrimaryName = "user"
        public static let foreignSecondaryName = "group"
    }
}
