import ErrorHandle

public extension PrivilegeModule {
    
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
        
        case resourceCreateFailed = "资源创建失败"
        case resourceDeleteFailed = "资源删除失败"
        case resourceUpdateFailed = "资源更新失败"
        
        case resourceDTOFailed = "资源数据 DTO 处理失败"
    }
}
