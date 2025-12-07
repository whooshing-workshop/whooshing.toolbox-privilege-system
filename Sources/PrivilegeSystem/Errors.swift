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
        
        // DTO 相关错误
        case userDTOFailed = "用户数据 DTO 处理失败"
        case userInfoDTOFailed = "用户信息数据 DTO 处理失败"
    }
}
