import ErrorHandle

public extension Query {
    enum Errcase: String, ErrList {
        case fetchResultFailed = "取得数据失败"
        case aggregateResultFailed = "汇总结果失败"
        case joinFetchResultFailed = "并表查询数据失败"
        case chunkResultFailed = "分块结果查询失败"
        case sortResultFailed = "排序结果查询失败"
    }
}
