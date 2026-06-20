import DTOBuilder

public struct Role: PolicyType {
    public typealias DTOModel = QRole
    public typealias Model = __SDBM.Role
    public static var namePrefix: String { "role" }
    public static var typeId: String { "role" }
}

typealias RoleType = Role

extension __SDBM {
    typealias RolePolicy = PolicyExp<RoleType>
}
