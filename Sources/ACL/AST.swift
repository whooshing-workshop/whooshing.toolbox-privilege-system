public indirect enum AST: Codable, Sendable {
    case variable(String)
    case number(Double)
    case string(String)
    case binary(op: Op, left: Self, right: Self)
    
    public enum CodingKeys: String, CodingKey, Sendable {
        case type, value, op, left, right
    }

    public init(from decoder: Decoder) throws {
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
            let op = try c.decode(Op.self, forKey: .op)
            let left = try c.decode(Self.self, forKey: .left)
            let right = try c.decode(Self.self, forKey: .right)
            self = .binary(op: op, left: left, right: right)

        default:
            preconditionFailure("未知的 AST 类型: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
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

public extension AST {
    enum Op: String, Codable, Sendable {
        // 算术
        case plus       = "+"
        case minus      = "-"
        case multi      = "*"
        case divide     = "/"

        // 比较运算符
        case equal          = "="
        case notEqual       = "<>"
        case less           = "<"
        case greater        = ">"
        case lessEqual      = "<="
        case greaterEqual   = ">="

        // 逻辑运算符
        case and        = "AND"
        case or         = "OR"
        case not        = "NOT"

        // 特殊逻辑
        case like       = "LIKE"
        case notLike    = "NOT LIKE"

        case `in`       = "IN"
        case notIn      = "NOT IN"

        case isNull     = "IS NULL"
        case isNotNull  = "IS NOT NULL"

        // 区间
        case between        = "BETWEEN"
        case notBetween     = "NOT BETWEEN"
    }
}
