public extension Censor {
    indirect enum Map: Sendable, Codable {
        case value(Value)
        case action(String, [Self])
    }
}
