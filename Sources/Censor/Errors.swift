import ErrorHandle

public extension Censor {
    enum Errcase: String, ErrList {
        case valueAssignFailed = "赋值失败"
        case argumentValueAssignFailed = "参数赋值失败"
        case realTypeCastFailed = "变量取值出错"
        case stringCastFailed = "String 类型解包失败"
        case sugarTypeDetectFailed = "语法糖类型推断失败"
        case arrayTypeDetectFailed = "数组类型推断失败"
    }
}
