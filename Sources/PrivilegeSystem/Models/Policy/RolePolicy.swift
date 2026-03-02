import Policy

extension Role: PolicyType {
    public typealias Model = Role
    public static var namePrefix: String { "role" }
    public static var typeId: String { "role" }
}

typealias RolePolicy = PolicyExp<Role>
