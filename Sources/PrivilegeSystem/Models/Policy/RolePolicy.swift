import Policy

extension Role: PolicyType {
    package typealias Model = Role
    package static var namePrefix: String { "role" }
    package static var typeId: String { "role" }
}

typealias RolePolicy = PolicyExp<Role>
