import ErrorHandle
import Foundation

extension Censor {
    protocol TypeDeclare: Sendable, Equatable, CustomStringConvertible {
        associatedtype RealType: Sendable
        
        static var name: String { get }
        var nullable: Bool { get }
        
        func set(nullable: Bool) -> Self
        
        var properties: [String: PropertyDeclare] { get }
        static var staticProperties: [String: PropertyDeclare] { get }
        
        var functions: [String: FunctionDeclare] { get }
        static var staticFunctions: [String: FunctionDeclare] { get }
        
        var prefixOperations: [Symbol.PrefixOperator: OperationDeclare.Prefix] { get }
        var postfixOperations: [Symbol.PostfixOperator: OperationDeclare.Suffix] { get }
        var infixOperations: [Symbol.InfixOperator: [OperationDeclare.Infix]] { get }
        
        static var propertyActions: [String: ExecutableAction] { get }
        static var functionActions: [String: ExecutableAction] { get }
        
        static var staticPropertieActions: [String: ExecutableAction] { get }
        static var staticFunctionActions: [String: ExecutableAction] { get }
        
        static var prefixOpActions: [Symbol.PrefixOperator: ExecutableAction] { get }
        static var postfixOpActions: [Symbol.PostfixOperator: ExecutableAction] { get }
        static var infixOpActions: [Symbol.InfixOperator: [String: ExecutableAction]] { get }
        
        func isMatch(value: Censor.Value) -> Bool
        
        func make(_ value: RealType?) -> Variable<Self>
//        func make(value: Value) -> Res<Variable<Self>, Censor.Errcase>
//        func realType(of value: Value) -> RealType
//        func optionalRealType(of value: Value) -> RealType?
        
        init(nullable: Bool)
    }

    struct Variable<T>: Sendable where T: TypeDeclare {
        let type: T
        let value: T.RealType?
        var declaredType: String { self.type.description }
        var optional: Bool { self.type.nullable }
        
//        func `is`(type: any TypeDeclare) -> Bool {
//            Swift.type(of: self.type).name == Swift.type(of: type).name &&
//            (value.isNull ?  type.nullable == true : true)
//        }

        fileprivate init(type: T, value: T.RealType?) {
            self.type = type
            self.value = value
        }
    }
}

extension Censor.Variable: Equatable where T.RealType: Equatable {}

extension Censor.TypeDeclare {
    var properties: [String: Censor.PropertyDeclare] { [:] }
    static var staticProperties: [String: Censor.PropertyDeclare] { [:] }
    var functions: [String: Censor.FunctionDeclare] { [:] }
    static var staticFunctions: [String: Censor.FunctionDeclare] { [:] }
    
    var prefixOperations: [Censor.Symbol.PrefixOperator: Censor.OperationDeclare.Prefix] { [:] }
    var postfixOperations: [Censor.Symbol.PostfixOperator: Censor.OperationDeclare.Suffix] { [:] }
    var infixOperations: [Censor.Symbol.InfixOperator: [Censor.OperationDeclare.Infix]] { [:] }
    
    static var propertyActions: [String: Censor.ExecutableAction] { [:] }
    static var functionActions: [String: Censor.ExecutableAction] { [:] }
    static var staticPropertieActions: [String: Censor.ExecutableAction] { [:] }
    static var staticFunctionActions: [String: Censor.ExecutableAction] { [:] }
    
    static var prefixOpActions: [Censor.Symbol.PrefixOperator: Censor.ExecutableAction] { [:] }
    static var postfixOpActions: [Censor.Symbol.PostfixOperator: Censor.ExecutableAction] { [:] }
    static var infixOpActions: [Censor.Symbol.InfixOperator: [String: Censor.ExecutableAction]] { [:] }
    
    func set(nullable: Bool) -> Self {
        .init(nullable: nullable)
    }
    
    func make(_ value: RealType?) -> Censor.Variable<Self> {
        .init(type: self, value: value)
    }
    
    func isMatch(value: Censor.Value) -> Bool {
        (self.nullable || !value.isNull) && (value is RealType?)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.nullable == rhs.nullable
    }
    
    var description: String {
        "\(Self.name)\(nullable ? "?" : "")"
    }
}

extension Censor.Variable {
    var storingValue: Censor.AST.StoringType {
        switch T.name {
        case Censor.StringType.name: return .string(value as! String?)
        case Censor.CharacterType.name: let c = value as! Character?; return .string((c != nil) ? String(c!) : nil)
        case Censor.IntegerType.name: return .integer(value as! Int64?)
        case Censor.DecimalType.name: return .decimal(value as! Decimal?)
        case Censor.DateType.name: let v = value as! Date?; return .string(v != nil ? Censor.DateType.dateFormatter.string(from: v!) : nil)
        case Censor.UUIDType.name: let v = value as! UUID?; return .string(v != nil ? v!.uuidString : nil)
        case Censor.BoolType.name: let v = value as! Bool?; return .string(v != nil ? (v! ? "true" : "false") : nil)
        default: preconditionFailure()
        }
    }
}

func == (lhs: any Censor.TypeDeclare, rhs: any Censor.TypeDeclare) -> Bool {
    type(of: lhs).name == type(of: rhs).name &&
    lhs.nullable == rhs.nullable
}

public extension Censor {
    struct AnyVariable: Sendable, CustomStringConvertible {
        let type: any TypeDeclare
        
        public let anyValue: Sendable?

        init<T: TypeDeclare>(_ variable: Variable<T>) {
            self.type = variable.type
            self.anyValue = variable.value
            self.storingValue = variable.storingValue
        }

        public let storingValue: Censor.AST.StoringType

        public var description: String {
            if let v = anyValue {
                return String(describing: v)
            } else {
                return Keyword.null.lexeme
            }
        }
        
        func asVariable<T: TypeDeclare>(of type: T.Type) -> Variable<T>? {
            guard let value = anyValue as? T.RealType?,
                  let specificType = self.type as? T else {
                return nil
            }
            return specificType.make(value)
        }
    }
}
