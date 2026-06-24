import DTOBuilder

public struct Role: PolicyType {
    public typealias DTOModel = QRole
    public typealias Model = __SDBM.Role
    public static var namePrefix: String { "role" }
    public static var typeId: String { "role" }
}

package typealias RoleType = Role

package extension __SDBM {
    typealias RolePolicy = PolicyExp<RoleType>
}
