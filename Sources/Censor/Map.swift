import ErrorHandle

public extension Censor {
    indirect enum Map: Sendable, Codable {
        // 语义：将常量加载到编号为 dst 的寄存器
        case loadConst(value: Value, dst: Int)
        // 语义：调用 action，输入数据来自 inputs 寄存器列表，结果存入 dst 寄存器
        case call(action: ActionKey, inputs: [Int], dst: Int)
    }
}
