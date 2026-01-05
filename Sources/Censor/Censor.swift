public struct Censor: @unchecked Sendable {
    static let actions: [ActionKey: ExecutableAction] = merge(
        getStructAction({ .instant(type: $1, name: $0, .property) }) { $0.propertyActions },
        getStructAction({ .instant(type: $1, name: $0, .function) }) { $0.functionActions },
        getStructAction({ .static(type: $1, name: $0, .property) }) { $0.staticPropertieActions },
        getStructAction({ .static(type: $1, name: $0, .function) }) { $0.staticFunctionActions },
        getStructAction({ .prefixOp(type: $1, $0) }) { $0.prefixOpActions },
        getStructAction({ .postfixOp(type: $1, $0) }) { $0.postfixOpActions },
        getInfixAction(),
        getAction(Symbol.sugars.map { (.sugar(type: $0.name), $0.action) })
    )
    
    public enum ActionKey: Codable, Hashable, CustomStringConvertible, Sendable {
        public enum Kind: String, Sendable, Codable, Hashable, CustomStringConvertible {
            case property
            case function
            
            public var description: String {
                switch self {
                case .property: "prop"
                case .function: "func"
                }
            }
        }
        
        case prefixOp(type: String, Symbol.PrefixOperator)
        case postfixOp(type: String, Symbol.PostfixOperator)
        case infixOp(type: String, Symbol.InfixOperator, returning: String)
        case instant(type: String, name: String, Kind)
        case `static`(type: String, name: String, Kind)
        case sugar(type: String)
        
        public var description: String {
            switch self {
            case .prefixOp(let type, let prefixOperator):                   "pref_op_\(type)_\(prefixOperator.rawValue)".lowercased()
            case .postfixOp(let type, let postfixOperator):                 "post_op_\(type)_\(postfixOperator.rawValue)".lowercased()
            case .infixOp(let type, let infixOperator, let returning):      "infi_op_\(type)_\(returning)_\(infixOperator.rawValue)".lowercased()
            case .instant(let type, let kind, let name):                    "\(kind)_\(type)_\(name)".lowercased()
            case .static(let type, let kind, let name):                     "static_\(kind)_\(type)_\(name)".lowercased()
            case .sugar(let type):                                          "sugar_\(type)".lowercased()
            }
        }
    }
    
}

fileprivate extension Censor {
    static func getStructAction<K>(
        _ key: (K, String) -> ActionKey,
        _ action: (any TypeDeclare.Type) -> [K: ExecutableAction]
    ) -> [ActionKey: ExecutableAction] {
        .init(
            uniqueKeysWithValues: Censor.basicTypes.flatMap {
                t in action(t).map {
                    (key($0.key, t.name), $0.value)
                }
            }
        )
    }
    
    static func getInfixAction() -> [ActionKey: ExecutableAction] {
        .init(
            uniqueKeysWithValues: Censor.basicTypes.flatMap {
                t in t.infixOpActions.flatMap { (symbol, group) in
                    group.map {
                        (.infixOp(type: t.name, symbol, returning: $0.key), $0.value)
                    }
                }
            }
        )
    }
    
    static func getAction(
        _ action: [(ActionKey, ExecutableAction)]
    ) -> [ActionKey: ExecutableAction] {
        .init(uniqueKeysWithValues: action)
    }
    
    static func merge<K, V>(_ dics: [K: V] ...) -> [K: V] {
        guard var res = dics.first else { return [:] }
        for dic in dics.dropFirst() {
            res = res.merging(dic) { _, new in new }
        }
        return res
    }
}
