import ACL

let DataModels: [any TdeMIG.Type] = [
    UserInfosModels,
    GroupModels,
    ACLModels,
    PivotModels
].flatMap { $0 }
