import Foundation

public extension Censor {
    indirect enum AST: Sendable {
        case value(AnyVariable)
        case trueType(String)
        case variable(String)   // 全局变量
        case property(String)
        case function(String, args: [Self])
        case forceCast
        case nilCoalescing(`default`: Self)
        case ternary(condition: Self, pass: Self, fail: Self)
        case array([Self])
        case arraySelector(index: Int)
        case chain(content: Self, next: Self)
        case scope(domain: String, content: Self)
        case prefix(operator: Operator.Prefix, right: Self)
        case postfix(operator: Operator.Postfix, left: Self)
        case infix(operator: Operator.Infix, left: Self, right: Self)

        public enum StoringType: Sendable {
            case string(String?)
            case integer(Int64?)
            case decimal(Decimal?)
        }
    }
}

public extension Censor.AST {
    enum CodingType: String, Codable, CaseIterable, Sendable {
        case value = "Value"
        case trueType = "TrueType"
        case variable = "Variable"
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

        case .trueType(let s):
            acl.type = .trueType
            acl.value = s
            return [acl]

        case .variable(let s):
            acl.type = .variable
            acl.value = s
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
                res.append(
                    contentsOf: arg.toACL(
                        parent: acl.id,
                        rule: rule ?? acl.id,
                        position: i
                    )
                )
            }

            return res

        case .forceCast:
            acl.type = .forceCast
            return [acl]

        case .nilCoalescing(let d):
            acl.type = .nilCoalescing

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: d.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 0
                )
            )

            return res

        case .ternary(let c, let p, let f):
            acl.type = .ternary

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: c.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 0
                )
            )
            res.append(
                contentsOf: p.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 1
                )
            )
            res.append(
                contentsOf: f.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 2
                )
            )

            return res

        case .array(let v):
            acl.type = .array

            var res: [ACLExp<T>] = [acl]
            for (i, value) in v.enumerated() {
                res.append(
                    contentsOf: value.toACL(
                        parent: acl.id,
                        rule: rule ?? acl.id,
                        position: i
                    )
                )
            }

            return [acl]

        case .arraySelector(let i):
            acl.type = .arraySelector
            acl.value = String(i)
            return [acl]

        case .chain(let c, let n):
            acl.type = .chain

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: c.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: -1
                )
            )
            res.append(
                contentsOf: n.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 1
                )
            )

            return res

        case .scope(let d, let content):
            acl.type = .scope
            acl.value = d
            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: content.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 0
                )
            )

            return res

        case .prefix(let op, let right):
            acl.type = .prefix
            acl.op = op.rawValue

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: right.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: -1
                )
            )

            return res

        case .postfix(let op, let left):
            acl.type = .suffix
            acl.op = op.rawValue

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: left.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 1
                )
            )

            return res

        case .infix(let op, let left, let right):
            acl.type = .infix
            acl.op = op.rawValue

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: left.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: -1
                )
            )
            res.append(
                contentsOf: right.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 1
                )
            )

            return res
        }
    }
}

extension Censor.AST: CustomStringConvertible {
    public var description: String {
        return "\n" + describe(node: self, prefix: "")
    }

    private func describe(node: Censor.AST, prefix: String) -> String {
        var str = ""

        switch node {
        case .value(let v):
            str += "Value(\(v))"

        case .trueType(let s):
            str += "TrueType(\(s))"

        case .variable(let s):
            str += "Variable(\(s))"

        case .property(let s):
            str += "Property(\(s))"

        case .function(let name, let args):
            str += "Function(\(name))"
            str += childrenDescription(children: args, prefix: prefix)

        case .forceCast:
            str += "ForceCast"

        case .nilCoalescing(let def):
            str += "NilCoalescing"
            str += childrenDescription(children: [def], prefix: prefix)

        case .ternary(let condition, let pass, let fail):
            str += "Ternary"
            str += childrenDescription(children: [condition, pass, fail], prefix: prefix)

        case .array(let items):
            str += "Array"
            str += childrenDescription(children: items, prefix: prefix)

        case .arraySelector(let index):
            str += "ArraySelector(\(index))"

        case .chain(let content, let next):
            str += "Chain"
            str += childrenDescription(children: [content, next], prefix: prefix)

        case .scope(let domain, let content):
            str += "Scope(\(domain))"
            str += childrenDescription(children: [content], prefix: prefix)

        case .prefix(let op, let right):
            str += "\(op)"
            str += childrenDescription(children: [right], prefix: prefix)

        case .postfix(let op, let left):
            str += "\(op)"
            str += childrenDescription(children: [left], prefix: prefix)

        case .infix(let op, let left, let right):
            str += "\(op)"
            str += childrenDescription(children: [left, right], prefix: prefix)
        }

        return str
    }

    private func childrenDescription(children: [Censor.AST], prefix: String) -> String {
        var result = ""
        for (index, child) in children.enumerated() {
            let isLast = index == children.count - 1
            let connector = isLast ? "└── " : "├── "
            let childPrefix = prefix + (isLast ? "    " : "│   ")

            result += "\n" + prefix + connector + describe(node: child, prefix: childPrefix)
        }
        return result
    }
}
