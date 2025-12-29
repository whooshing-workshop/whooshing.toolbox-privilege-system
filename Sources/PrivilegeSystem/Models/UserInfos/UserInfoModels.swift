import Censor

let UserInfosModels: [any TdeMIG.Type] = [
    User.MIG.self,
    User.Info.MIG.self,
    Token.MIG.self,
    User.Info.Extended<User.Info.Phone>.MIG.self,
    User.Info.Extended<User.Info.Address>.MIG.self,
    User.Info.Extended<User.Info.AlternateEmail>.MIG.self
]
