import ErrorHandle
import Foundation
import Censor

public struct Executor {
    
    public enum Macro: String {
        case resource = "RESOURCE"
        case operations = "OPERATIONS"
    }
    
//    public let globals: [String: Censor.Variable] = [:]
}


//import ErrorHandle
//import Foundation
//import Censor
//
//public struct Executorr {
//    
//    public enum Macro: String {
//        case resource = "RESOURCE"
//        case operations = "OPERATIONS"
//    }
//    
//    public let globals: [String: ValueWrapper] = [:]
//    
//    public func execute<R: Resource>(
//        with expression: Censor,
//        for resource: R,
//        operations: Set<R.Op>,
//        in module: PriviliegeModule
//    ) -> Res<Bool, Errcase> {
//        guard case let .scope(domain, content) = expression.ast else {
//            return .failure(.evaluateFailed, "未提供域描述", category: .external)
//        }
//        
//        guard domain == module.id.uuidString else {
//            return .failure(.evaluateFailed, "该表达式不适用于该服务模块", category: .external)
//        }
//        
//        switch content {
//        case .prefix(let op, let right):
//        case .suffix(let op, let left):
//        case .infix(let op, let left, let right):
//            
//        case .scope: return .failure(.evaluateFailed, "scope 重复定义", category: .external)
//        
//        case .variable, .value, .forceCast, .array, .arraySelector, .chain:
//            return evaluate(valueTree: content, for: resource, operations: operations).flatMap { value in
//                guard
//                    value.isBasic(type: .bool),
//                    value.nullable == false
//                else {
//                    return .failure(.evaluateFailed, "返回值应当为 Bool，实际上为 \(value.declaredType)", category: .external)
//                }
//                
//                return .success(value.value as! Bool)
//            }
//        }
//    }
//    
//    func evaluate(
//        operationTree: AST
//    ) -> Res<Bool, Errcase> {
//        
//    }
//    
//    func evaluate<R: Resource>(
//        valueTree: AST,
//        for resource: R,
//        operations: Set<R.Op>
//    ) -> Res<ValueWrapper, Errcase> {
//        
//        var chain: [String] = []
//        return evaluate(ast: valueTree, value: nil)
//        
//        func evaluate(
//            ast: AST,
//            value: ValueWrapper?
//        ) -> Res<ValueWrapper, Errcase> {
//            switch ast {
//            case .variable(let string):
//                chain.append(string)
//                
//                return self.evaluate(
//                    variable: string,
//                    from: value,
//                    for: resource,
//                    operations: operations,
//                    chain: chain
//                ).flatMap { res in
//                    guard res.validate() else {
//                        return .failure(.valueTreeEvaluateFailed, "变量 \(log: chain.joined(separator: ".")) 的声明类型为 \(res.declaredType)，但实际为 \(String(describing: res.value.self))", category: .internal)
//                    }
//                    
//                    return .success(res)
//                }
//                
//            case .value(let string, let type, let nullable):
//                return self.evaluate(value: string, type: type, nullable: nullable)
//                
//            case .forceCast:
//                guard let v = value else {
//                    return .failure(.valueTreeEvaluateFailed, "强制解包仅允许置于元素之后", category: .external)
//                }
//                guard v.nullable == true else {
//                    return .failure(.valueTreeEvaluateFailed, "无法解包非空值", category: .external)
//                }
//                return .success(v.set(nullable: false))
//                
//            case .arraySelector(let i):
//                guard
//                    let v = value,
//                    v.isArray == true,
//                    let items = v.value as? [Any?]
//                else {
//                    return .failure(.valueTreeEvaluateFailed, "数组索引选择器仅允许置于数组之后", category: .external)
//                }
//                let res = items[i]
//                return .success(.init(value: res, type: v.type, nullable: v.nullable, isArray: v.nullable ? res is [Any?]? : res is [Any?]))
//                
//            case .array(let array):
//                guard let first = array.first else {
//                    return .success(.init(value: [], type: .any, nullable: false, isArray: true))
//                }
//                
//                return evaluate(ast: first, value: value).flatMap { valueWrapper in
//                    var r = Res<Void, Errcase>.success()
//                    var res = [valueWrapper.value]
//                    var nullable = valueWrapper.nullable
//                    for item in array.dropFirst() {
//                        r = r.flatMap { _ in
//                            evaluate(ast: item, value: value).flatMap { valueWrapper2 in
//                                if !nullable && valueWrapper2.nullable {
//                                    nullable = true
//                                }
//                                guard valueWrapper2.type == valueWrapper.type else {
//                                    return .failure(.valueTreeEvaluateFailed, "数组中类型不一致", category: .external)
//                                }
//                                res.append(valueWrapper2.value)
//                                return .success()
//                            }
//                        }
//                    }
//                    return r.map { _ in
//                        .init(value: res, type: valueWrapper.type, nullable: nullable, isArray: true)
//                    }
//                }
//                
//            case .chain(let content, let next):
//                return evaluate(ast: content, value: value).flatMap { left in
//                    evaluate(ast: content, value: left)
//                }
//                
//            default: return .failure(.valueTreeEvaluateFailed, "所提供的结构并非值 AST 树", category: .internal)
//            }
//        }
//    }
//    
//    func evaluate<R: Resource>(
//        variable: String,
//        from base: ValueWrapper?,
//        for resource: R,
//        operations: Set<R.Op>,
//        chain: [String]
//    ) -> Res<ValueWrapper, Errcase> {
//        if let base = base {
//            guard
//                base.type == nil,
//                let object = base.value as? ObservableModel,
//                let varAction = resource.properties[variable]
//            else {
//                return .failure(.variableEvaluateFailed, "无法从变量 \(log: chain.dropLast().joined(separator: ".")) 中取得 \(log: variable)", category: .external)
//            }
//            
//            return Result<Any?, Error> {
//                try varAction.value()
//            }.map { value in
//                .init(value: value, type: varAction.type, nullable: varAction.nullable, isArray: varAction.isArray)
//            }.mapError { err in
//                .init(.variableEvaluateFailed, "变量 \(log: chain.joined(separator: ".")) 取值时出错: \(err)", category: .external)
//            }
//        } else {
//            if variable == Macro.resource.rawValue {
//                return .success(.init(value: resource, type: nil, nullable: false, isArray: false))
//            } else if variable == Macro.operations.rawValue {
//                return .success(.init(value: [R.Op](operations), type: nil, nullable: false, isArray: true))
//            } else if let g = globals[variable] {
//                return .success(g)
//            } else {
//                return .failure(.variableEvaluateFailed, "无法找到变量 \(log: chain.joined(separator: "."))", category: .external)
//            }
//        }
//    }
//    
//    func evaluate(
//        value: String,
//        type: AST.ValueType,
//        nullable: Bool
//    ) -> Res<ValueWrapper, Errcase> {
//        guard value != Macro.null.rawValue else {
//            if nullable {
//                return .success(.init(value: nil, type: type, nullable: true, isArray: false))
//            } else {
//                return .failure(.valueEvaluateFailed, "无法为非空变量设定 NULL", category: .external)
//            }
//        }
//        
//        switch type {
//        case .string: return .success(.init(value: value, type: .string, nullable: nullable, isArray: false))
//            
//        case .number:
//            guard let num = Decimal(string: value) else {
//                return .failure(Errcase.valueEvaluateFailed, "从值 \(log: value) 转为 Number 类型时失败，格式不合法", category: .external)
//            }
//            return .success(.init(value: num, type: .number, nullable: nullable, isArray: false))
//            
//        case .date:
//            guard let d = Self.dateFormatter.date(from: value) else {
//                return .failure(Errcase.valueEvaluateFailed, "从值 \(log: value) 转为 Date 类型时失败，格式不合法(例：2025-12-26T15:36:18Z)", category: .external)
//            }
//            return .success(.init(value: d, type: .date, nullable: nullable, isArray: false))
//            
//        case .uuid:
//            guard let u = UUID(uuidString: value) else {
//                return .failure(Errcase.valueEvaluateFailed, "从值 \(log: value) 转为 UUID 类型时失败，格式不合法(例：DEDF2334-27B8-41F9-9887-62414E7C01F4)", category: .external)
//            }
//            return .success(.init(value: u, type: .uuid, nullable: nullable, isArray: false))
//            
//        case .bool:
//            guard
//                let b = switch value {
//                case "true": true
//                case "false": false
//                default: nil
//                }
//            else {
//                return .failure(.valueEvaluateFailed, "从值 \(log: value) 转为 Bool 类型时失败，格式不合法")
//            }
//            return .success(.init(value: b, type: .bool, nullable: nullable, isArray: false))
//            
//        case .any:
//            return .success(.init(value: value, type: .any, nullable: nullable, isArray: false))
//        }
//    }
//}
//
//extension ValueWrapper {
//    func validate() -> Bool {
//        type == nil ? value is ObservableModel : type!.isMatch(value: value)
//    }
//    
//    func `is`(type t: AST.ValueType?) -> Bool {
//        type == t && (t == nil ? value is ObservableModel : t!.isMatch(value: value))
//    }
//    
//    func `isBasic`(type t: AST.ValueType) -> Bool {
//        guard let tt = type else { return false }
//        return tt == t && t.isMatch(value: value)
//    }
//    
//    func set(nullable: Bool) -> Self {
//        .init(value: value, type: type, nullable: nullable, isArray: isArray)
//    }
//}
