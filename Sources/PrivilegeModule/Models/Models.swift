import DTOBuilder

public extension PM {
    enum __DBM{}
}

extension PrivilegeModule {
    static var DataModels: [any TdeMIG.Type] {[
        __SDBM.AnyResource.MIG.self,
        __DBM.Privilege.MIG.self,
        __DBM.PrivilegeAnyResourcePivot.MIG.self
    ]}
}
