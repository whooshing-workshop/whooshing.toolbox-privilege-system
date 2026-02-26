import ErrorHandle

public extension PrivilegeSystem {
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
        case regoLoadFailed = "REGO 策略加载失败"
        case sqlLoadFailed = " SQL 函数加载失败"
        
        // 登陆注册相关错误
        case userRegisterFailed = "用户注册失败"
        case userLoginFailed = "用户登陆失败"
        case userAuthenticateFailed = "用户口令认证失败"
        case accountDataFetchFailed = "账号数据检索失败"
        case userPasswordChangeFailed = "用户密码修改失败"
        
        // 用户信息相关错误
        case userInfoAddFailed = "用户信息数据创建失败"
        case userInfoDeleteFailed = "用户信息数据删除失败"
        case userInfoUpdateFailed = "用户信息数据更新失败"
        case userInfoQueryFailed = "用户信息查询失败"
        
        // 权限策略相关错误
        case policyCheckFailed = "权限策略检查失败"
        case policyCreateFailed = "权限策略创建失败"
        case policyDeleteFailed = "权限策略删除失败"
        
        // 角色相关错误
        case roleCreateFailed = "角色数据创建失败"
        case roleDeleteFailed = "角色数据删除失败"
        case roleUpdateFailed = "角色数据更新失败"
        case roleAppointUserFailed = "角色任命到用户失败"
        case roleAppointGroupFailed = "角色任命到用户组失败"
        case roleAppointGroupUserFailed = "角色任命到用户组内用户失败"
        case roleDismissUserFailed = "角色从用户撤职组失败"
        case roleDismissGroupFailed = "角色从用户组撤职组失败"
        case roleDismissGroupUserFailed = "角色从用户组内用户撤职失败"
        
        // 角色组相关错误
        case groupCreateFailed = "群组数据创建失败"
        case groupDeleteFailed = "群组数据删除失败"
        case groupUpdateFailed = "群组数据更新失败"
        case userJoinGroupFailed = "用户加入群组失败"
        case userKickGroupFailed = "用户从群组移除失败"
        case userGroupRelationQueryFailed = "用户与群组关系查询失败"
        
        // 域权限相关错误
        case domainCreateFailed = "域权限数据创建失败"
        case domainDeleteFailed = "域权限数据删除失败"
        case domainUpdateFailed = "域权限数据更新失败"
        case domainAssignUserFailed = "域权限指派到用户失败"
        case domainAssignGroupFailed = "域权限指派到用户组失败"
        case domainUnassignUserFailed = "域权限从用户取消指派失败"
        case domainUnassignGroupFailed = "域权限从用户组取消指派失败"
        
        // DTO 相关错误
        case userDTOFailed = "用户数据 DTO 处理失败"
        case userInfoDTOFailed = "用户信息数据 DTO 处理失败"
        case tokenDTOFailed = "口令数据 DTO 处理失败"
        case roleDTOFailed = "角色数据 DTO 处理失败"
        case groupDTOFailed = "用户群组数据 DTO 处理失败"
        case domainDTOFailed = "域权限数据 DTO 处理失败"
        case userInGroupDTOFailed = "用户群组关系数据 DTO 处理失败"
        case censorDTOFailed = "Censor DTO 处理失败"
        
        // 仲裁相关错误
        case arbitrateFailed = "权限仲裁失败"
        case arbitrationDataCollectFailed = "仲裁数据收集失败"
    }
}
