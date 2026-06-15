import Policy

extension PrivilegeModule {
    static var DataModels: [any TdeMIG.Type] {[
        __AnyResource.MIG.self,
        __Privilege.MIG.self,
        PrivilegeAnyResourcePivot.MIG.self
    ]}
}
