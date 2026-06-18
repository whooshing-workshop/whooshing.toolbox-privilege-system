import ErrorHandle

public extension DTO {
    enum Errcase: String, ErrList {
        case modelQueryFailed = "数据库查询模型失败"
        case modelNotExist = "数据库模型不存在"
        case siblingsLoadFailed = "Siblings 关系加载失败"
        case superLoadFailed = "Super 关系加载失败"
        case optionalSuperLoadFailed = "OptionalSuper 关系加载失败"
        case subsLoadFailed = "Subs 关系加载失败"
        case subLoadFailed = "Sub 关系加载失败"
        case optionalSubLoadFailed = "OptionalSub 关系加载失败"
    }
}
