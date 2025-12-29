import ErrorHandle
import Foundation

extension Censor {
    public enum Keyword: String {
        case null = "NULL"
        case `in` = "IN"
    }

    public protocol TypeDeclare: Sendable, Equatable, CustomStringConvertible {
        associatedtype RealType
        
        static var name: String { get }
        var nullable: Bool { get }
        
        func set(nullable: Bool) -> Self
        
        static var properties: [String: Property] { get }
        static var staticProperties: [String: Property] { get }
        
        static var functions: [String: Function] { get }
        static var staticFunctions: [String: Function] { get }
        
        static var prefixOperations: [Operator: [Operation.Prefix]] { get }
        static var suffixOperations: [Operator: [Operation.Suffix]] { get }
        static var infixOperations: [Operator: [Operation.Infix]] { get }
        
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
    static var properties: [String: Censor.Property] { [:] }
    static var staticProperties: [String: Censor.Property] { [:] }
    static var functions: [String: Censor.Function] { [:] }
    static var staticFunctions: [String: Censor.Function] { [:] }
    
    static var prefixOperations: [Censor.Operator: [Censor.Operation.Prefix]] { [:] }
    static var suffixOperations: [Censor.Operator: [Censor.Operation.Suffix]] { [:] }
    static var infixOperations: [Censor.Operator: [Censor.Operation.Infix]] { [:] }
    
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
