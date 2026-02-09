import Policy

extension PrivilegeModule {
    typealias PrivilegePolicy = PolicyExp<Privilege>
}

extension PrivilegeModule.Privilege: PolicyType {
    public typealias Model = PrivilegeModule.Privilege
    public static var namePrefix: String { "privilege" }
    public static var typeId: String { "privilege" }
}
