import Policy

extension PrivilegeModule {
    static var DataModels: [any TdeMIG.Type] {[
        AnyResource.MIG.self,
        Privilege.MIG.self,
        PrivilegeResourcePivot.MIG.self
    ]}
}
