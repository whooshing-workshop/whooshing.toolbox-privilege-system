import Foundation

public extension Censor {
    indirect enum AST: Sendable {
        case value(Variable)
        case property(String)
        case function(String, args: [Self])
        case forceCast
        case nilCoalescing(`default`: Self)
        case ternary(condition: Self, pass: Self, fail: Self)
        case array([Self])
        case arraySelector(index: Int)
        case chain(content:Self, next: Self)
        case scope(domain: String, content: Self)
        case prefix(operator: Operator, right: Self)
        case suffix(operator: Operator, left: Self)
        case infix(operator: Operator, left: Self, right: Self)
    }
}

public extension Censor.AST {
    enum CodingType: String, Codable, CaseIterable, Sendable {
        case value = "Value"
        case property = "Property"
        case function = "Function"
        case forceCast = "ForceCast"
        case nilCoalescing = "NilCoalescing"
        case ternary = "Ternary"
        case array = "Array"
        case arraySelector = "ArraySelector"
        case chain = "Chain"
        case scope = "Scope"
        case prefix = "Prefix"
        case suffix = "Suffix"
        case infix = "Infix"
    }
    
    func toACL<T: ACLType>(
        _ type: T.Type = T.self,
        parent: UUID? = nil,
        rule: UUID? = nil,
        position: Int? = nil
    ) -> [ACLExp<T>] {
        let acl = ACLExp<T>()
        acl.id = UUID()
        acl.$parent.id = parent
        acl.$rule.id = rule ?? acl.id!
        acl.position = position

        switch self {
        case .value(let v):
            acl.type = .value
            switch v.storingValue {
            case .string(let s): acl.value = s
            case .integer(let i): acl.valueInt = i
            case .decimal(let d): acl.valueDecimal = d
            }
            acl.valueType = .init(from: v.type)
            acl.valueNullable = v.type.nullable
            return [acl]

        case .property(let s):
            acl.type = .property
            acl.value = s
            return [acl]
            
        case .function(let n, let args):
            acl.type = .function
            acl.value = n
            
            var res: [ACLExp<T>] = [acl]
            for (i, arg) in args.enumerated() {
                res.append(contentsOf: arg.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: i
                ))
            }
            
            return res
            
        case .forceCast:
            acl.type = .forceCast
            return [acl]

        case .nilCoalescing(let d):
            acl.type = .nilCoalescing
            
            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: d.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 0
            ))
            
            return res
            
        case .ternary(let c, let p, let f):
            acl.type = .ternary
            
            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: c.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 0
            ))
            res.append(contentsOf: p.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 1
            ))
            res.append(contentsOf: f.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 2
            ))

            return res
            
        case .array(let v):
            acl.type = .array
            
            var res: [ACLExp<T>] = [acl]
            for (i, value) in v.enumerated() {
                res.append(contentsOf: value.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: i
                ))
            }
            
            return [acl]

        case .arraySelector(let i):
            acl.type = .arraySelector
            acl.value = String(i)
            return [acl]

        case .chain(let c, let n):
            acl.type = .chain

            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: c.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: -1
            ))
            res.append(contentsOf: n.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 1
            ))

            return res

        case .scope(let d, let content):
            acl.type = .scope
            acl.value = d
            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: content.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 0
            ))

            return res

        case .prefix(let op, let right):
            acl.type = .prefix
            acl.op = op

            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: right.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: -1
            ))

            return res

        case .suffix(let op, let left):
            acl.type = .suffix
            acl.op = op

            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: left.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 1
            ))

            return res

        case .infix(let op, let left, let right):
            acl.type = .infix
            acl.op = op

            var res: [ACLExp<T>] = [acl]
            res.append(contentsOf: left.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: -1
            ))
            res.append(contentsOf: right.toACL(
                parent: acl.id,
                rule: rule ?? acl.id,
                position: 1
            ))

            return res
        }
    }
}
//import ErrorHandle
//import NIOAdvanced
//import Foundation
//
//public indirect enum AST: Sendable {
//    public enum ValueType: String, Codable, Sendable, CaseIterable {
//        case string = "String"
//        case number = "Number"
//        case date = "Date"
//        case uuid = "UUID"
//        case bool = "Bool"
//        case any = "Any"
//        
//        public func isMatch(value: Any?) -> Bool {
//            switch self {
//            case .string: value == nil || value! is String
//            case .number: value == nil || value! is any Numeric
//            case .date: value == nil || value! is Date
//            case .uuid: value == nil || value! is UUID
//            case .bool: value == nil || value! is Bool
//            case .any: true
//            }
//        }
//    }
//    
//    case variable(String)
//    case value(String, type: ValueType, nullable: Bool)
//    case forceCast
//    case array([Self])
//    case arraySelector(index: Int)
//    case chain(content: Self, next: Self)
//    case scope(domain: String, content: Self)
//    case prefix(operator: Operator, right: Self)
//    case suffix(operator: Operator, left: Self)
//    case infix(operator: Operator, left: Self, right: Self)
//}
//    
//extension AST: Codable {
//    public enum CodingKeys: String, CodingKey, Sendable {
//        case type, value, valueType, valueNullable, op, left, right
//    }
//    
//    public enum CodingType: String, Codable, Sendable, CaseIterable {
//        case variable = "variable"
//        case value = "value"
//        case forceCast = "force_cast"
//        case chain = "chain"
//        case array = "array"
//        case arraySelector = "array_selector"
//        case scope = "scope"
//        case prefix = "prefix"
//        case suffix = "suffix"
//        case infix = "infix"
//    }
//
//    public init(from decoder: Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        let type = try c.decode(CodingType.self, forKey: .type)
//
//        switch type {
//        case .variable:
//            let value = try c.decode(String.self, forKey: .value)
//            self = .variable(value)
//
//        case .value:
//            let value = try c.decode(String.self, forKey: .value)
//            let type = try c.decode(ValueType.self, forKey: .valueType)
//            let nullable = try c.decode(Bool.self, forKey: .valueNullable)
//            self = .value(value, type: type, nullable: nullable)
//        
//        case .forceCast:
//            self = .forceCast
//            
//        case .array:
//            let value = try c.decode([Self].self, forKey: .value)
//            self = .array(value)
//            
//        case .arraySelector:
//            let value = try c.decode(Int.self, forKey: .value)
//            self = .arraySelector(index: value)
//            
//        case .chain:
//            let left = try c.decode(Self.self, forKey: .left)
//            let right = try c.decode(Self.self, forKey: .right)
//            self = .chain(content: left, next: right)
//            
//        case .scope:
//            let op = try c.decode(Operator.self, forKey: .op)
//            let domain = try c.decode(String.self, forKey: .value)
//            let content = try c.decode(Self.self, forKey: .right)
//            self = .scope(domain: domain, content: content)
//            
//        case .prefix:
//            let op = try c.decode(Operator.self, forKey: .op)
//            let right = try c.decode(Self.self, forKey: .right)
//            self = .prefix(operator: op, right: right)
//            
//        case .suffix:
//            let op = try c.decode(Operator.self, forKey: .op)
//            let left = try c.decode(Self.self, forKey: .left)
//            self = .suffix(operator: op, left: left)
//            
//        case .infix:
//            let op = try c.decode(Operator.self, forKey: .op)
//            let left = try c.decode(Self.self, forKey: .left)
//            let right = try c.decode(Self.self, forKey: .right)
//            self = .infix(operator: op, left: left, right: right)
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//
//        switch self {
//        case .variable(let v):
//            try c.encode(CodingType.variable, forKey: .type)
//            try c.encode(v, forKey: .value)
//
//        case .value(let v, let t, let n):
//            try c.encode(CodingType.value, forKey: .type)
//            try c.encode(t, forKey: .valueType)
//            try c.encode(v, forKey: .value)
//            try c.encode(n, forKey: .valueNullable)
//
//        case .forceCast:
//            try c.encode(CodingType.forceCast, forKey: .type)
//            
//        case .array(let v):
//            try c.encode(CodingType.array, forKey: .type)
//            try c.encode(v, forKey: .value)
//            
//        case .arraySelector(let i):
//            try c.encode(CodingType.arraySelector, forKey: .type)
//            try c.encode(i, forKey: .value)
//            
//        case .chain(let content, let n):
//            try c.encode(CodingType.chain, forKey: .type)
//            try c.encode(content, forKey: .left)
//            try c.encode(n, forKey: .right)
//            
//        case .scope(let d, let content):
//            try c.encode(CodingType.scope, forKey: .type)
//            try c.encode(d, forKey: .value)
//            try c.encode(content, forKey: .right)
//            
//        case .prefix(let op, let right):
//            try c.encode(CodingType.prefix, forKey: .type)
//            try c.encode(op, forKey: .op)
//            try c.encode(right, forKey: .right)
//            
//        case .suffix(let op, let left):
//            try c.encode(CodingType.infix, forKey: .type)
//            try c.encode(op, forKey: .op)
//            try c.encode(left, forKey: .left)
//            
//        case .infix(let op, let left, let right):
//            try c.encode(CodingType.infix, forKey: .type)
//            try c.encode(op, forKey: .op)
//            try c.encode(left, forKey: .left)
//            try c.encode(right, forKey: .right)
//        }
//    }
//}
//
//public extension AST {
//    func toACL<T: ACLType>(
//        _ type: T.Type = T.self,
//        parent: UUID? = nil,
//        rule: UUID? = nil,
//        position: ACLPosition? = nil
//    ) -> [ACLExp<T>] {
//        let acl = ACLExp<T>()
//        acl.id = UUID()
//        acl.$parent.id = parent
//        acl.$rule.id = rule ?? acl.id!
//        acl.position = position
//        
//        switch self {
//        case .variable(let variable):
//            acl.type = .variable
//            acl.value = variable
//            return [acl]
//            
//        case .value(let v, let t, let n):
//            acl.type = .value
//            acl.value = v
//            acl.valueType = t
//            acl.valueNullable = n
//            return [acl]
//            
//        case .forceCast:
//            acl.type = .forceCast
//            return [acl]
//            
//        case .array(let v):
//            acl.type = .array
//            acl.value = "#Array#"
//            return [acl]
//            
//        case .arraySelector(let i):
//            acl.type = .arraySelector
//            acl.value = String(i)
//            return [acl]
//            
//        case .chain(let c, let n):
//            acl.type = .chain
//            
//            var res: [ACLExp<T>] = [acl]
//            res.append(contentsOf: c.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .left
//            ))
//            res.append(contentsOf: n.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .right
//            ))
//            
//            return res
//            
//        case .scope(let d, let content):
//            acl.type = .scope
//            acl.value = d
//            var res: [ACLExp<T>] = [acl]
//            res.append(contentsOf: content.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .right
//            ))
//            
//            return res
//            
//        case .prefix(let op, let right):
//            acl.type = .prefix
//            acl.op = op
//            
//            var res: [ACLExp<T>] = [acl]
//            res.append(contentsOf: right.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .right
//            ))
//            
//            return res
//            
//        case .suffix(let op, let left):
//            acl.type = .suffix
//            acl.op = op
//            
//            var res: [ACLExp<T>] = [acl]
//            res.append(contentsOf: left.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .left
//            ))
//            
//            return res
//            
//        case .infix(let op, let left, let right):
//            acl.type = .infix
//            acl.op = op
//            
//            var res: [ACLExp<T>] = [acl]
//            res.append(contentsOf: left.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .left
//            ))
//            res.append(contentsOf: right.toACL(
//                parent: acl.id,
//                rule: rule ?? acl.id,
//                position: .right
//            ))
//            
//            return res
//        }
//    }
//}
