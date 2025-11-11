import ErrorHandle

public extension PrivilegeModule {
    
    enum Errcase: String, ErrList {
        case databaseInitFailed = "数据库初始化失败"
    }
}
