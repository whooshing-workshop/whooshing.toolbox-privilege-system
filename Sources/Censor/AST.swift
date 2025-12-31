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
    func toMap() -> Censor.Map {
        
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
