import Foundation

public extension Censor {
    indirect enum AST: Sendable {
        case value(AnyVariable)
        case trueType(String)
        case rule(any Rule.Define, contents: [Self])
        case global(String)
        case property(String)
        case keyword(Keyword.Define)
        case function(String, args: [Self])
        case array([Self])
        case arraySelector(index: Int, at: Self)
        case prefix(operator: Symbol.PrefixOperator, right: Self)
        case postfix(operator: Symbol.PostfixOperator, left: Self)
        case infix(operator: Symbol.InfixOperator, left: Self, right: Self)

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
        case rule = "Rule"
        case global = "Global"
        case property = "Property"
        case keyword = "Keyword"
        case function = "Function"
        case array = "Array"
        case arraySelector = "ArraySelector"
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

        case .global(let s):
            acl.type = .global
            acl.value = s
            return [acl]

        case .property(let s):
            acl.type = .property
            acl.value = s
            return [acl]
            
        case .keyword(let k):
            acl.type = .keyword
            acl.value = k.lexeme
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

        case .arraySelector(let i, let a):
            acl.type = .arraySelector
            acl.value = String(i)
            
            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: a.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: -1
                )
            )

            return res

        case .prefix(let op, let right):
            acl.type = .prefix
            acl.op = op.operator.lexeme

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
            acl.op = op.operator.lexeme

            var res: [ACLExp<T>] = [acl]
            res.append(
                contentsOf: left.toACL(
                    parent: acl.id,
                    rule: rule ?? acl.id,
                    position: 1
                )
            )

            return res

        case .rule(let r, let c):
            acl.type = .rule
            acl.value = r.name
            
            var res: [ACLExp<T>] = [acl]
            for (i, child) in c.enumerated() {
                res.append(
                    contentsOf: child.toACL(
                        parent: acl.id,
                        rule: rule ?? acl.id,
                        position: i
                    )
                )
            }
            return res

        case .infix(let op, let left, let right):
            acl.type = .infix
            acl.op = op.operator.lexeme

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

        case .global(let s):
            str += "Global(\(s))"

        case .property(let s):
            str += "Property(\(s))"

        case .keyword(let k):
            str += "Keyword(\(k.lexeme))"
            
        case .function(let name, let args):
            str += "Function(\(name))"
            str += childrenDescription(children: args, prefix: prefix)

        case .array(let items):
            str += "Array"
            str += childrenDescription(children: items, prefix: prefix)

        case .arraySelector(let index, let array):
            str += "ArraySelector(\(index))"
            str += childrenDescription(children: [array], prefix: prefix)

        case .prefix(let op, let right):
            str += "\(op.operator)"
            str += childrenDescription(children: [right], prefix: prefix)

        case .postfix(let op, let left):
            str += "\(op.operator)"
            str += childrenDescription(children: [left], prefix: prefix)

        case .rule(let r, let c):
            str += "\(r.description)"
            str += childrenDescription(children: c, prefix: prefix)

        case .infix(let op, let left, let right):
            str += "\(op.operator)"
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
