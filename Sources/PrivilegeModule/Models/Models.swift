import Policy

extension PrivilegeModule {
    static var DataModels: [any TdeMIG.Type] {[
        PrivilegePolicy.MIG.self,
        Privilege.MIG.self,
        PrivilegeResourcePivot.MIG.self
    ]}
}
