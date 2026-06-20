import DTOBuilder

public extension __SDBM {
    typealias UserRolePivot = Pivot<Pivots.UserRole>
}

public extension __SDBM.Pivots {
    struct UserRole: PivotType {
        public typealias PrimaryModel = __SDBM.User
        public typealias SecondaryModel = __SDBM.Role
        
        public static let foreignPrimaryName = "user"
        public static let foreignSecondaryName = "role"
        
        public static let foreignSecondaryType = DatabaseSchema.DataType.uuid
    }
}
