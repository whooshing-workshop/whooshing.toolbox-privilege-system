import ErrorHandle
import Foundation

extension Censor {
    public protocol TypeDeclare: Sendable, Equatable, CustomStringConvertible {
        associatedtype RealType
        
        static var name: String { get }
        var nullable: Bool { get }
        
        func set(nullable: Bool) -> Self
        
        var properties: [String: PropertyDeclare] { get }
        static var staticProperties: [String: PropertyDeclare] { get }
        
        var functions: [String: FunctionDeclare] { get }
        static var staticFunctions: [String: FunctionDeclare] { get }
        
        var prefixOperations: [Operator.Prefix: OperationDeclare.Prefix] { get }
        var suffixOperations: [Operator.Postfix: OperationDeclare.Suffix] { get }
        var infixOperations: [Operator.Infix: [OperationDeclare.Infix]] { get }
        
        static var propertyActions: [String: ExecutableAction] { get }
        static var functionActions: [String: ExecutableAction] { get }
        
        static var staticPropertieActions: [String: ExecutableAction] { get }
        static var staticFunctionActions: [String: ExecutableAction] { get }
        
        static var prefixOpActions: [Operator.Prefix: ExecutableAction] { get }
        static var suffixOpActions: [Operator.Postfix: ExecutableAction] { get }
        static var infixOpActions: [Operator.Infix: [String: ExecutableAction]] { get }
        
        func make(_ value: RealType?) -> Res<Variable, Censor.Errcase>
        func make(value: Value) -> Res<Variable, Censor.Errcase>
        func realType(of value: Value) -> RealType
        func optionalRealType(of value: Value) -> RealType?
        
        init(nullable: Bool)
    }

    public struct Variable: Sendable {
        public let type: any TypeDeclare
        public let value: Value
        public var declaredType: String { self.type.description }
        public var optional: Bool { self.type.nullable }
        
        public func `is`(type: any TypeDeclare) -> Bool {
            Swift.type(of: self.type).name == Swift.type(of: type).name &&
            (value.isNull ?  type.nullable == true : true)
        }
        
        init(type: any TypeDeclare, value: Value) {
            self.type = type
            self.value = value
        }
    }
}

public extension Censor.TypeDeclare {
    var properties: [String: Censor.PropertyDeclare] { [:] }
    static var staticProperties: [String: Censor.PropertyDeclare] { [:] }
    var functions: [String: Censor.FunctionDeclare] { [:] }
    static var staticFunctions: [String: Censor.FunctionDeclare] { [:] }
    
    var prefixOperations: [Censor.Operator.Prefix: Censor.OperationDeclare.Prefix] { [:] }
    var suffixOperations: [Censor.Operator.Postfix: Censor.OperationDeclare.Suffix] { [:] }
    var infixOperations: [Censor.Operator.Infix: [Censor.OperationDeclare.Infix]] { [:] }
    
    static var propertyActions: [String: Censor.ExecutableAction] { [:] }
    static var functionActions: [String: Censor.ExecutableAction] { [:] }
    static var staticPropertieActions: [String: Censor.ExecutableAction] { [:] }
    static var staticFunctionActions: [String: Censor.ExecutableAction] { [:] }
    
    static var prefixOpActions: [Censor.Operator.Prefix: Censor.ExecutableAction] { [:] }
    static var suffixOpActions: [Censor.Operator.Postfix: Censor.ExecutableAction] { [:] }
    static var infixOpActions: [Censor.Operator.Infix: [String: Censor.ExecutableAction]] { [:] }
    
    func set(nullable: Bool) -> Self {
        .init(nullable: nullable)
    }
    
    func make(_ value: RealType?) -> Res<Censor.Variable, Censor.Errcase> {
        make(value: .init(value))
    }
    
    func make(value: Censor.Value) -> Res<Censor.Variable, Censor.Errcase> {
        guard isMatch(value: value) else {
            return .failure(.valueAssignFailed, "无法将 \(log: value) 赋值与 \(self)")
        }
        
        return .success(.init(type: self, value: value))
    }
    
    func isMatch(value: Censor.Value) -> Bool {
        (self.nullable || !value.isNull) && (value is RealType?)
    }
    
    func realType(of value: Censor.Value) -> RealType {
        guard !self.nullable else {
            preconditionFailure("类型为可选值")
        }
        
        let optionValue = optionalRealType(of: value)
        
        guard let v = optionValue else {
            preconditionFailure("应当为非空值，却得到 \(log: Censor.Keyword.null.rawValue)")
        }
        return v
    }
    
    func optionalRealType(of value: Censor.Value) -> RealType? {
        guard let v = value as? RealType? else {
            preconditionFailure("类型应当为 \(String(describing: RealType.self))，却得到 \(log: value)")
        }
        
        return v
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.nullable == rhs.nullable
    }
    
    var description: String {
        "\(Self.name)\(nullable ? "?" : "")"
    }
}

public extension Censor.Variable {
    enum StoringType {
        case string(String?)
        case integer(Int64?)
        case decimal(Decimal?)
    }
    
    var storingValue: StoringType {
        switch Swift.type(of: self.type).name {
        case Censor.StringType.name: return .string(value.cast())
        case Censor.CharacterType.name: let c = value.cast(as: Character?.self); return .string((c != nil) ? String(c!) : nil)
        case Censor.IntegerType.name: return .integer(value.cast())
        case Censor.DecimalType.name: return .decimal(value.cast())
        case Censor.DateType.name: let v = value.cast(as: Date?.self); return .string(v != nil ? Censor.DateType.dateFormatter.string(from: v!) : nil)
        case Censor.UUIDType.name: let v = value.cast(as: UUID?.self); return .string(v != nil ? v!.uuidString : nil)
        case Censor.BoolType.name: let v = value.cast(as: Bool?.self); return .string(v != nil ? (v! ? "true" : "false") : nil)
        default: preconditionFailure()
        }
    }
}

public func == (lhs: any Censor.TypeDeclare, rhs: any Censor.TypeDeclare) -> Bool {
    type(of: lhs).name == type(of: rhs).name &&
    lhs.nullable == rhs.nullable
}
