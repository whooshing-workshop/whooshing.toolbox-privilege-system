import DTOBuilder

let UserInfosModels: [any TdeMIG.Type] = [
    __SDBM.User.MIG.self,
    __SDBM.User.Info.MIG.self,
    __SDBM.Token.MIG.self,
    __SDBM.User.Info.Extended<__SDBM.User.Info.Phone>.MIG.self,
    __SDBM.User.Info.Extended<__SDBM.User.Info.Address>.MIG.self,
    __SDBM.User.Info.Extended<__SDBM.User.Info.AlternateEmail>.MIG.self
]
