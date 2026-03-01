import ErrorHandle

public extension Query {
    enum Errcase: String, ErrList {
        case fetchResultFailed = "取得数据失败"
        case countResultFailed = "取得结果计数失败"
    }
}
