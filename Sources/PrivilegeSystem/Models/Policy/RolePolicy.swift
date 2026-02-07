import Policy

extension Role: PolicyType {
    typealias Model = Role
    static var namePrefix: String { "role" }
}

typealias RolePolicy = PolicyExp<Role>
