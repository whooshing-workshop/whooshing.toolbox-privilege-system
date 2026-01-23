
import Foundation

public extension Censor {
    struct AST: Sendable {
        let range: SourceRange
        public let content: Content
        
        init(content: Content, range: SourceRange) {
            self.content = content
            self.range = range
        }
    
        public typealias StoringType = Content.StoringType

        public indirect enum Content: Sendable {
            case value(AnyVariable)
            case trueType(String)
            case rule(AnyRule, contents: [AST])
            case identifier(String)
            case function(String, args: [AST])
            case array([AST])
            case arraySelector(index: Int, at: AST)
            case prefix(operator: Symbol.PrefixOperator, right: AST)
            case postfix(operator: Symbol.PostfixOperator, left: AST)
            case infix(operator: Symbol.InfixOperator, left: AST, right: AST)

            public enum StoringType: Sendable {
                case string(String?)
                case integer(Int64?)
                case decimal(Decimal?)
            }
            
            static func rule<R: Rule.Define>(_ rule: R, contents: [AST]) -> Self {
                return .rule(.init(rule), contents: contents)
            }
        }
    }
}

public extension Censor.AST {
    enum CodingType: String, Codable, CaseIterable, Sendable {
        case value = "Value"
        case trueType = "TrueType"
        case rule = "Rule"
        case identifier = "Identifier"
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

        switch self.content {
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

        case .identifier(let s):
            acl.type = .identifier
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

            return res

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

        // 1. Determine node signature
        switch node.content {
        case .value(let v):
            str += "Value(\(v))"
        case .trueType(let s):
            str += "TrueType(\(s))"
        case .identifier(let s):
            str += "Identifier(\(s))"
        case .function(let name, _):
            str += "Function(\(name))"
        case .array:
            str += "Array"
        case .arraySelector(let index, _):
            str += "ArraySelector(\(index))"
        case .prefix(let op, _):
            str += "\(op.operator)"
        case .postfix(let op, _):
            str += "\(op.operator)"
        case .rule(let r, _):
            str += "\(r.description)"
        case .infix(let op, _, _):
            str += "\(op.operator)"
        }
        
        // 2. Append Range
        str += " <\(node.range)>"
        
        // 3. Append Children
        switch node.content {
        case .function(_, let args):
            str += childrenDescription(children: args, prefix: prefix)
        case .array(let items):
            str += childrenDescription(children: items, prefix: prefix)
        case .arraySelector(_, let array):
            str += childrenDescription(children: [array], prefix: prefix)
        case .prefix(_, let right):
            str += childrenDescription(children: [right], prefix: prefix)
        case .postfix(_, let left):
            str += childrenDescription(children: [left], prefix: prefix)
        case .rule(_, let c):
            str += childrenDescription(children: c, prefix: prefix)
        case .infix(_, let left, let right):
            str += childrenDescription(children: [left, right], prefix: prefix)
        default:
            break
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
