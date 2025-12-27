import ErrorHandle

public extension AST.Operator {
    enum Errcase: String, ErrList {
        case typingFailed = "进行类型解析时失败"
        case equalEvaluateFailed = "相等逻辑判断失败"
        case plusEvaluateFailed = "相加逻辑判断失败"
    }
}
