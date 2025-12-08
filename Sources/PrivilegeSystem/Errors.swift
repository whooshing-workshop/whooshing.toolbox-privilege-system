import ErrorHandle

public extension PrivilegeSystem {
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
        
        // 登陆注册相关错误
        case userRegisterFailed = "用户注册失败"
        case userLoginFailed = "用户登陆失败"
        case userAuthenticateFailed = "用户口令认证失败"
        case accountDataFetchFailed = "账号数据检索失败"
        
        // 用户信息相关错误
        case userInfoAddFailed = "用户信息数据创建失败"
        case userInfoDeleteFailed = "用户信息数据删除失败"
        case userInfoUpdateFailed = "用户信息数据更新失败"
        case userInfoQueryFailed = "用户信息查询失败"
        
        // 角色相关错误
        case roleCreateFailed = "角色数据创建失败"
        case roleDeleteFailed = "角色数据删除失败"
        case roleUpdateFailed = "角色数据更新失败"
        
        // 角色组相关错误
        case groupCreateFailed = "群组数据创建失败"
        case groupDeleteFailed = "群组数据删除失败"
        case groupUpdateFailed = "群组数据更新失败"
        
        // 域权限相关错误
        case domainCreateFailed = "域权限数据创建失败"
        case domainDeleteFailed = "域权限数据删除失败"
        case domainUpdateFailed = "域权限数据更新失败"
        
        // DTO 相关错误
        case userDTOFailed = "用户数据 DTO 处理失败"
        case userInfoDTOFailed = "用户信息数据 DTO 处理失败"
        case tokenDTOFailed = "口令数据 DTO 处理失败"
        case roleDTOFailed = "角色数据 DTO 处理失败"
        case groupDTOFailed = "用户群组数据 DTO 处理失败"
        case domainDTOFailed = "域权限数据 DTO 处理失败"
    }
}
