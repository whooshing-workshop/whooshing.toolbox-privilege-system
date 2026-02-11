import Policy

extension PrivilegeModule {
    static var DataModels: [any TdeMIG.Type] {
        ResourceList.allCases.map { $0.migration }
        + [
            Privilege.MIG.self,
            PrivilegeResourcePivot.MIG.self
        ]
    }
}
