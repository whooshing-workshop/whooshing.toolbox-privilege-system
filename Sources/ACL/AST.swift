import ErrorHandle
import NIOAdvanced
import Foundation

public indirect enum AST: Sendable {
    
    public enum ValueType: String, Codable, Sendable, CaseIterable {
        case string = "string"
        case number = "number"
        case date = "date"
        case uuid = "uuid"
    }
    
    case variable(String)
    case value(String, type: ValueType)
    case binary(op: Op, left: Self, right: Self)
}
    
extension AST: Codable {
    public enum CodingKeys: String, CodingKey, Sendable {
        case type, value, valueType, op, left, right
    }
    
    public enum CodingType: String, Codable, Sendable, CaseIterable {
        case variable = "variable"
        case value = "value"
        case binary = "binary"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(CodingType.self, forKey: .type)

        switch type {
        case .variable:
            let value = try c.decode(String.self, forKey: .value)
            self = .variable(value)

        case .value:
            let value = try c.decode(String.self, forKey: .value)
            let type = try c.decode(ValueType.self, forKey: .valueType)
            self = .value(value, type: type)

        case .binary:
            let op = try c.decode(Op.self, forKey: .op)
            let left = try c.decode(Self.self, forKey: .left)
            let right = try c.decode(Self.self, forKey: .right)
            self = .binary(op: op, left: left, right: right)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .variable(let v):
            try c.encode(CodingType.variable, forKey: .type)
            try c.encode(v, forKey: .value)

        case .value(let v, let t):
            try c.encode(CodingType.value, forKey: .type)
            try c.encode(t, forKey: .valueType)
            try c.encode(v, forKey: .value)

        case .binary(let op, let left, let right):
            try c.encode(CodingType.binary, forKey: .type)
            try c.encode(op, forKey: .op)
            try c.encode(left, forKey: .left)
            try c.encode(right, forKey: .right)
        }
    }
}

public extension AST {
    enum Op: String, Codable, Sendable, CaseIterable {
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

public extension AST {
    func toACL<T: ACLType>(
        _ type: T.Type = T.self,
        parent: UUID? = nil,
        rule: UUID? = nil,
        position: ACLPosition? = nil
    ) -> [ACLExp<T>] {
        let acl = ACLExp<T>()
        acl.id = UUID()
        acl.$parent.id = parent
        acl.$rule.id = rule ?? acl.id!
        acl.position = position
        
        switch self {
        case .variable(let variable):
            acl.type = .variable
            acl.value = variable
            return [acl]
        case .value(let v, type: let t):
            acl.type = .value
            acl.value = v
            acl.valueType = t
            return [acl]
        case .binary(let op, let left, let right):
            acl.type = .binary
            acl.op = op
            
            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: left.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: .left
            ))
            res.append(contentsOf: right.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: .right
            ))
            
            return res
        }
    }
}
