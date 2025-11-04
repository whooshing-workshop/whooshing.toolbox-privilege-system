import ErrorHandle

public extension PrivilegeSystem {
    
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
        
        // 登陆注册相关错误
        case userRegisterFailed = "用户注册失败"
        case userLoginFailed = "用户登陆失败"
        case userAuthenticateFailed = "用户口令认证失败"
        case accountDataFetchFailed = "账号数据检索失败"
    }
}
