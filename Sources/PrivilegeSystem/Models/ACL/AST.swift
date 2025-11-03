indirect enum AST: Codable {
    case variable(String)
    case number(Double)
    case string(String)
    case binary(op: String, left: Self, right: Self)

    enum CodingKeys: String, CodingKey {
        case type, value, op, left, right
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)

        switch type {
        case "variable":
            let value = try c.decode(String.self, forKey: .value)
            self = .variable(value)

        case "number":
            let value = try c.decode(Double.self, forKey: .value)
            self = .number(value)

        case "string":
            let value = try c.decode(String.self, forKey: .value)
            self = .string(value)

        case "binary":
            let op = try c.decode(String.self, forKey: .op)
            let left = try c.decode(Self.self, forKey: .left)
            let right = try c.decode(Self.self, forKey: .right)
            self = .binary(op: op, left: left, right: right)

        default:
            preconditionFailure("未知的 AST 类型: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .variable(let v):
            try c.encode("variable", forKey: .type)
            try c.encode(v, forKey: .value)

        case .number(let v):
            try c.encode("number", forKey: .type)
            try c.encode(v, forKey: .value)

        case .string(let v):
            try c.encode("string", forKey: .type)
            try c.encode(v, forKey: .value)

        case .binary(let op, let left, let right):
            try c.encode("binary", forKey: .type)
            try c.encode(op, forKey: .op)
            try c.encode(left, forKey: .left)
            try c.encode(right, forKey: .right)
        }
    }
}
