import ErrorHandle

public extension PrivilegeInterpreter {
    enum Errcase: String, ErrList {
        case evaluateFailed = "权限表达式检查失败"
        case valueTreeEvaluateFailed = "值节点树检查失败"
        case variableEvaluateFailed = "变量节点检查失败"
        case valueEvaluateFailed = "字面量节点检查失败"
    }
}
