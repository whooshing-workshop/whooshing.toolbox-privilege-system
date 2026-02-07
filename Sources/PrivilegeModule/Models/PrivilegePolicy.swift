import Policy

extension Privilege: PolicyType {
    public typealias Model = Privilege
    public static var namePrefix: String { "privilege" }
}

typealias PrivilegePolicy = PolicyExp<Privilege>
