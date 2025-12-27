import ErrorHandle
import Foundation

public struct ValueWrapper {
    public let value: Any?
    public let type: TypeDefine
    public var declaredType: String { self.type.description }
    public var optional: Bool { self.type.nullable }
    
    public struct TypeDefine: Equatable, CustomStringConvertible {
        public let type: AST.ValueType?
        public let nullable: Bool
        public let isArray: Bool
        
        public init(type: AST.ValueType?, nullable: Bool, isArray: Bool) {
            self.type = type
            self.nullable = nullable
            self.isArray = isArray
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.type == rhs.type &&
            lhs.nullable == rhs.nullable &&
            lhs.isArray == rhs.isArray
        }
        
        public var description: String {
            "\(isArray ? "[" : "")\(type?.rawValue ?? "ObservableModel")\(isArray ? "]" : "")\(nullable ? "?" : "")"
        }
    }
    
    public init(value: Any?, type: AST.ValueType?, nullable: Bool, isArray: Bool) {
        self = .init(value: value, type: .init(type: type, nullable: nullable, isArray: isArray))
    }
    
    public init(value: Any?, type: TypeDefine) {
        self.value = value
        self.type = type
        guard self.is(type: self.type) else {
            preconditionFailure("提供的类型 \(type) 与值 \(log: value ?? AST.keywordNull) 不符")
        }
    }
    
    public func `is`(type: TypeDefine) -> Bool {
        self.type.type == type.type &&
        (self.value == nil ? type.nullable == true : true) &&
        self.type.isArray == type.isArray
    }
    
    func typing<G, T>(
        with value: Self,
        as type: G.Type,
        _ action: (G, G) -> Res<T, AST.Operator.Errcase>
    ) -> Res<T, AST.Operator.Errcase> {
        doubleTyping(with: value, as: (G.self, G.self), action)
    }
    
    func doubleTyping<G, D, T>(
        with value: Self,
        as type: (G.Type, D.Type),
        _ action: (G, D) -> Res<T, AST.Operator.Errcase>
    ) -> Res<T, AST.Operator.Errcase> {
        let p1 = get(v: self, as: G.self)
        let p2 = get(v: value, as: D.self)
        
        return action(p1, p2)
        
        func get<U>(v: Self, as: U.Type) -> U {
            guard !v.type.nullable else {
                preconditionFailure("提供的类型 \(v.type) 为可选，解包失败")
            }
            
            if let val = v.value {
                guard let p = val as? U else {
                    preconditionFailure("提供的类型 \(v.type) 与值 \(log: val) 不符")
                }
                return p
            } else {
                preconditionFailure("提供的类型 \(v.type) 为可选，且值为 \(log: AST.keywordNull)，解包失败")
            }
        }
    }
    
    func optionalTyping<G, T>(
        with value: Self,
        as type: G.Type,
        _ action: (G?, G?) -> Res<T, AST.Operator.Errcase>
    ) -> Res<T, AST.Operator.Errcase> {
        optionalDoubleTyping(with: value, as: (G.self, G.self), action)
    }
    
    func optionalDoubleTyping<G, D, T>(
        with value: Self,
        as type: (G.Type, D.Type),
        _ action: (G?, D?) -> Res<T, AST.Operator.Errcase>
    ) -> Res<T, AST.Operator.Errcase> {
        let p1 = get(v: self, as: G.self)
        let p2 = get(v: value, as: D.self)
        
        return action(p1, p2)
        
        func get<U>(v: Self, as: U.Type) -> U? {
            if let val = v.value {
                guard let p = val as? U else {
                    preconditionFailure("提供的类型 \(v.type) 与值 \(log: val) 不符")
                }
                return p
            } else {
                guard v.type.nullable else {
                    preconditionFailure("提供的类型 \(v.type) 与值 \(log: AST.keywordNull) 不符")
                }
                return nil
            }
        }
    }
}

public extension AST {
    static let keywordNull = "NULL"
    static let dateFormatter = ISO8601DateFormatter()
    
    enum Operator {
        public protocol Common: Codable, Sendable {
            static var text: String { get }
        }
        
        public protocol Binary: Common {
            func binaryCheck(result: ValueWrapper) -> Bool
        }

        public protocol Infix: Common {
            func execute(left: ValueWrapper, right: ValueWrapper) -> Res<ValueWrapper, Errcase>
        }

        public protocol Prefix: Common {
            func execute(right: ValueWrapper) -> Res<ValueWrapper, Errcase>
        }

        public protocol Suffix: Common {
            func execute(left: ValueWrapper) -> Res<ValueWrapper, Errcase>
        }
    }
    
//    enum Operator: String, Codable, Sendable, CaseIterable {
//        case plus       = "+"
//        case minus      = "-"
//        case multi      = "*"
//        case divide     = "/"
//        case mode       = "%"
//        case exp        = "^"
//
//        case equal          = "=="
//        case notEqual       = "!="
//        case less           = "<"
//        case greater        = ">"
//        case lessEqual      = "<="
//        case greaterEqual   = ">="
//
//        case and        = "&"
//        case or         = "|"
//        case not        = "!"
//
//        case like       = "~"
//        case notLike    = "!~"
//
//        case `in`       = "IN"
//        case notIn      = "!IN"
//    }
}

public extension AST.Operator {
    struct Plus: Infix, Prefix {
        public static let text = "+"
        public func execute(left: ValueWrapper, right: ValueWrapper) -> Res<ValueWrapper, Errcase> {
            guard !left.optional && !right.optional else {
                return .failure(.plusEvaluateFailed, "无法将 \(left.type) 与 \(right.type) 相加", category: .external)
            }
            
            switch left.type.type {
            case .string:
                let returnType = ValueWrapper.TypeDefine(type: .string, nullable: false, isArray: false)
                let r: Res<String, Errcase> =
                switch right.type.type {
                case .string: left.typing(with: right, as: String.self) { .success($0 + $1) }
                case .number: left.doubleTyping(with: right, as: (String.self, Decimal.self)) { .success($0 + $1.description) }
                case .date: left.doubleTyping(with: right, as: (String.self, Date.self)) { .success($0 + AST.dateFormatter.string(from: $1)) }
                case .bool: left.doubleTyping(with: right, as: (String.self, Bool.self)) { .success($0 + String($1)) }
                case .any, .uuid: .failure(.plusEvaluateFailed, "无法将 \(left.type) 与 \(right.type) 相加", category: .external)
                case .none: preconditionFailure("预期为非空，却得到 \(log: AST.keywordNull)")
                }
                
                return r.map { value in
                    .init(value: value, type: returnType)
                }
            case .number:
                let returnType = ValueWrapper.TypeDefine(type: .string, nullable: false, isArray: false)
                let r: Res<String, Errcase> =
                switch right.type.type {
                case .string: left.typing(with: right, as: String.self) { .success($0 + $1) }
                case .number: left.doubleTyping(with: right, as: (String.self, Decimal.self)) { .success($0 + $1.description) }
                case .date: left.doubleTyping(with: right, as: (String.self, Date.self)) { .success($0 + AST.dateFormatter.string(from: $1)) }
                case .bool: left.doubleTyping(with: right, as: (String.self, Bool.self)) { .success($0 + String($1)) }
                case .any, .uuid: .failure(.plusEvaluateFailed, "无法将 \(left.type) 与 \(right.type) 相加", category: .external)
                case .none: preconditionFailure("预期为非空，却得到 \(log: AST.keywordNull)")
                }
                
                return r.map { value in
                    .init(value: value, type: returnType)
                }
                
            case .date:
            case .bool:
            case .any, .uuid:
            case .none: preconditionFailure("预期为非空，却得到 \(log: AST.keywordNull)")
            }
            
        }
        
        public func execute(right: ValueWrapper) -> ErrorHandle.Res<ValueWrapper, AST.Operator.Errcase> {
            
        }
    }
}

public extension AST.Operator {
    struct Equal: Infix, Binary {
        public static let text = "=="
        public func execute(left: ValueWrapper, right: ValueWrapper) -> Res<ValueWrapper, Errcase> {
            guard left.is(type: right.type) else {
                return .failure(.equalEvaluateFailed, "操作数类型不一致，无法将 \(left.type) 与 \(right.type) 相比较")
            }
            
            let returnType = ValueWrapper.TypeDefine(type: .bool, nullable: false, isArray: false)
            
            let result: Res<Bool, Errcase> =
            switch left.type.type {
            case .string: left.optionalTyping(with: right, as: String.self) { .success($0 == $1) }
            case .number: left.optionalTyping(with: right, as: Decimal.self) { .success($0 == $1) }
            case .date: left.optionalTyping(with: right, as: Date.self) { .success($0 == $1) }
            case .uuid: left.optionalTyping(with: right, as: UUID.self) { .success($0 == $1) }
            case .bool: left.optionalTyping(with: right, as: Bool.self) { .success($0 == $1) }
            case .any: .failure(.equalEvaluateFailed, "无法将 \(left.type) 与 \(right.type) 进行比较", category: .external)
            case .none: .failure(.equalEvaluateFailed, "无法将 \(left.type) 与 \(right.type) 进行比较", category: .external)
            }
            
            return result.map { res in
                ValueWrapper(value: res, type: returnType)
            }.flatMap { res in
                guard binaryCheck(result: res) else {
                    return .failure(.equalEvaluateFailed, "对结果进行 Binary 判断失败", category: .internal)
                }
                return .success(res)
            }
        }
    }
}

public extension AST.Operator.Binary {
    func binaryCheck(result: ValueWrapper) -> Bool {
        result.type == .init(type: .bool, nullable: false, isArray: false) &&
        result.value as? Bool != nil
    }
}

extension ISO8601DateFormatter: @unchecked @retroactive Sendable {}
