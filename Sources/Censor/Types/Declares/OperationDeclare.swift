import ErrorHandle

extension Censor {
    public enum Operator: String, Sendable, Codable, CaseIterable {
        case plus           = "+"
        case minus          = "-"
        case multi          = "*"
        case divide         = "/"
        case mode           = "%"
        case exp            = "^"

        case equal          = "="
        case less           = "<"
        
        case and            = "&"
        case or             = "|"
        
        case greater        = ">"
        case lessEqual      = "<="
        case greaterEqual   = ">="
    }

    public struct Property: Sendable {
        public let returns: any TypeDeclare
        public let action: @Sendable (Value) -> Res<Value, Errcase>
        
        init(
            returns: any TypeDeclare,
            action: @Sendable @escaping (Value) -> Res<Value, Errcase>
        ) {
            self.returns = returns
            self.action = action
        }
        
        public init(@PropertyBuilder _ content: () -> Property) {
            self = content()
        }
    }
    
    public struct Function: Sendable {
        public let returns: any TypeDeclare
        public let argument: ArgumentDeclare
        public let action: @Sendable (Value, _ args: [Value]) -> Res<Value, Errcase>
        
        init(
            returns: any TypeDeclare,
            argument: ArgumentDeclare,
            action: @Sendable @escaping (Value, _ arg: [Value]) -> Res<Value, Errcase>
        ) {
            self.returns = returns
            self.argument = argument
            self.action = action
        }
        
        public init(@FunctionBuilder _ content: () -> Function) {
            self = content()
        }
    }
    
    @resultBuilder
    public struct PropertyBuilder {
        public static func buildBlock(
            _ returns: any TypeDeclare,
            _ action: @escaping @Sendable (Value) -> Res<Value, Errcase>
        ) -> Property {
            Property(returns: returns, action: action)
        }
    }
    
    @resultBuilder
    public struct FunctionBuilder {
        public static func buildBlock(
            _ returns: any TypeDeclare,
            _ argument: ArgumentDeclare,
            _ action: @escaping @Sendable (Value, _ args: [Value]) -> Res<Value, Errcase>
        ) -> Function {
            Function(returns: returns, argument: argument, action: action)
        }
    }

    public enum Operation {
        public struct Prefix: Sendable {
            public let selfNullable: Bool
            public let returns: any TypeDeclare
            public let action: @Sendable (_ right: Value) -> Res<Value, Errcase>
            
            init(
                returns: any TypeDeclare,
                selfNullable: Bool,
                action: @Sendable @escaping (_: Value) -> Res<Value, Errcase>
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
                self.action = action
            }
            
            public init(@PrefixBuilder _ content: () -> Prefix) {
                self = content()
            }
        }

        public struct Suffix: Sendable {
            public let selfNullable: Bool
            public let returns: any TypeDeclare
            public let action: @Sendable (_ left: Value) -> Res<Value, Errcase>
            
            init(
                returns: any TypeDeclare,
                selfNullable: Bool,
                action: @Sendable @escaping (_: Value) -> Res<Value, Errcase>
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
                self.action = action
            }
            
            public init(@SuffixBuilder _ content: () -> Operation.Suffix) {
                self = content()
            }
        }

        public struct Infix: Sendable {
            public let selfNullable: Bool
            public let returns: any TypeDeclare
            public let right: any TypeDeclare
            public let action: @Sendable (_ left: Value, _ right: Value) -> Res<Value, Errcase>
            
            init(
                returns: any TypeDeclare,
                selfNullable: Bool,
                right: any TypeDeclare,
                action: @Sendable @escaping (_: Value, _: Value) -> Res<Value, Errcase>
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
                self.right = right
                self.action = action
            }
            
            public init(@InfixBuilder _ content: () -> Operation.Infix) {
                self = content()
            }
        }
        
        @resultBuilder
        public struct InfixBuilder {
            public static func buildBlock(
                _ returns: any TypeDeclare,
                _ selfNullable: Bool,
                _ right: any TypeDeclare,
                _ action: @escaping @Sendable (Value, Value) -> Res<Value, Errcase>) -> Operation.Infix
            {
                Operation.Infix(returns: returns, selfNullable: selfNullable, right: right, action: action)
            }
        }

        @resultBuilder
        public struct PrefixBuilder {
            public static func buildBlock(
                _ returns: any TypeDeclare,
                _ selfNullable: Bool,
                _ action: @escaping @Sendable (Value) -> Res<Value, Errcase>) -> Operation.Prefix
            {
                Operation.Prefix(returns: returns, selfNullable: selfNullable, action: action)
            }
        }

        @resultBuilder
        public struct SuffixBuilder {
            public static func buildBlock(
                _ returns: any TypeDeclare,
                _ selfNullable: Bool,
                _ action: @escaping @Sendable (Value) -> Res<Value, Errcase>) -> Operation.Suffix
            {
                Operation.Suffix(returns: returns, selfNullable: selfNullable, action: action)
            }
        }
    }

    static func Return(_ type: @escaping @Sendable () -> any TypeDeclare) -> any TypeDeclare { type() }
    static func Action(_ action: @escaping @Sendable (Value) -> Res<Value, Errcase>) -> @Sendable (Value) -> Res<Value, Errcase> { action }
    static func FunctionAction(_ action: @escaping @Sendable (Value, [Value]) -> Res<Value, Errcase>) -> @Sendable (Value, [Value]) -> Res<Value, Errcase> { action }
    static func InfixAction(_ action: @escaping @Sendable (Value, Value) -> Res<Value, Errcase>) -> @Sendable (Value, Value) -> Res<Value, Errcase> { action }
}
