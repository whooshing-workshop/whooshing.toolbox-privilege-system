import ErrorHandle

public extension PrivilegeModule {
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
        case opaInitFailed = "OPA 初始化失败"
        
        case privilegeCreateFailed = "资源权限创建失败"
        case privilegeDeleteFailed = "资源权限删除失败"
        case privilegeUpdateFailed = "资源权限更新失败"
        case privilegeAttachResourceFailed = "资源权限附加到资源失败"
        case privilegeDetachResourceFailed = "资源权限从资源解除失败"
        case privilegeFetchFailed = "资源权限拉取失败"
        case privilegeCheckFailed = "资源权限检查失败"
        
        case resourceCreateFailed = "资源创建失败"
        case resourceDeleteFailed = "资源删除失败"
        case resourceUpdateFailed = "资源更新失败"
        
        case privilegeDTOFailed = "资源权限数据 DTO 处理失败"
        case resourceDTOFailed = "资源数据 DTO 处理失败"
    }
}
