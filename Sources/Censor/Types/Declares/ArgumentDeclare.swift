import ErrorHandle

extension Censor {
    public struct ArgumentDeclare: Sendable {
        public let labels: [String?]
        public let types: [@Sendable () -> any TypeDeclare]
        public let defaults: [Value?]
        
        public struct Define: Sendable {
            public let label: String?
            public let type: @Sendable() -> any TypeDeclare
            public let `default`: Value?
        }
        
        init(
            @ArgumentDeclareBuilder
            _ components: () -> [ArgumentDeclare.Define]
        ) {
            var labels: [String?] = []
            var types: [@Sendable () -> any TypeDeclare] = []
            var defaults: [Value?] = []
            for define in components() {
                labels.append(define.label)
                types.append(define.type)
                defaults.append(define.default)
            }
            self.labels = labels
            self.types = types
            self.defaults = defaults
        }
        
        func validate(_ values: [Value?]) -> Res<[Value], Censor.Errcase> {
            guard values.count == labels.count else {
                return .failure(.argumentValueAssignFailed, "参数个数不正确，预期为 \(labels.count) 个，却得到 \(values.count) 个", category: .external)
            }
            
            var res: [Value] = []
            
            for (i, value) in values.enumerated() {
                guard let v = value ?? defaults[i] else {
                    return .failure(.argumentValueAssignFailed, "第 \(i) 参数未赋值", category: .external)
                }
                
                guard types[i]().isMatch(value: v) else {
                    return .failure(.argumentValueAssignFailed, "无法将 \(log: v) 赋值与 \(types[i]())", category: .external)
                }
                
                res.append(v)
            }
            return .success(res)
        }
    }

    //public struct ArgumentVariable: Sendable {
    //    public let declare: ArgumentDeclare
    //    public let values: [Value?]
    //
    //    public let startIndex: Int = 0
    //
    //    fileprivate init(declare: ArgumentDeclare, values: [Value?]) {
    //        self.declare = declare
    //        self.values = values
    //    }
    //}
    //
    //extension ArgumentVariable: Collection {
    //    public var endIndex: Int { values.count }
    //    public func index(after i: Int) -> Int { i + 1 }
    //
    //    public subscript(position: Int) -> (type: any TypeDeclare, value: Value) {
    //        get {
    //            (type: self.declare.types[position], value: values[position] ?? self.declare.defaults[position]!)
    //        }
    //    }
    //
    //    public func cast<T>(of position: Int, as: T.Type = T.self) -> T {
    //        let value = self.values[position] ?? self.declare.defaults[position]!
    //        guard let v = value as? T else {
    //            preconditionFailure("无法将 \(log: value) cast 为 \(String(describing: T.self)) 类型")
    //        }
    //        return v
    //    }
    //}
}

infix operator >-

public func >- (left: (String?, @Sendable () -> any Censor.TypeDeclare), right: Censor.Value?) -> Censor.ArgumentDeclare.Define {
    .init(label: left.0, type: left.1, default: right)
}

@resultBuilder
public struct ArgumentDeclareBuilder: Sendable {
    public static func buildBlock(_ components: Censor.ArgumentDeclare.Define...) -> [Censor.ArgumentDeclare.Define] {
        components
    }
}

public extension Result where Success == Censor.Value {
    static func succ(_ value: Any?) -> Self {
        .success(.init(value))
    }
}
