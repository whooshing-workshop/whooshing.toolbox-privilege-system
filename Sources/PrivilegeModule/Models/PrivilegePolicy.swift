import Policy

extension Privilege: PolicyType {
    public typealias Model = Privilege
    public static var namePrefix: String { "privilege" }
    public static var typeId: String { "privilege" }
}

typealias PrivilegePolicy = PolicyExp<Privilege>
