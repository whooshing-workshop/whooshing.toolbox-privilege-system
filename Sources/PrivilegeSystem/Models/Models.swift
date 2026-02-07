import Policy

let DataModels: [any TdeMIG.Type] = [
    UserInfosModels,
    GroupModels,
    PolicyModels,
    PivotModels
].flatMap { $0 }
