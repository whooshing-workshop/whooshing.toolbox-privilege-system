import ErrorHandle

public extension Censor {
    struct PropertyDeclare: Sendable {
        public let returns: any TypeDeclare
        
        init(
            returns: any TypeDeclare
        ) {
            self.returns = returns
        }
        
        public init(@PropertyBuilder _ content: () -> Self) {
            self = content()
        }
    }
    
    struct FunctionDeclare: Sendable {
        public let returns: any TypeDeclare
        public let argument: ArgumentDeclare
        
        init(
            returns: any TypeDeclare,
            argument: ArgumentDeclare
        ) {
            self.returns = returns
            self.argument = argument
        }
        
        public init(@FunctionBuilder _ content: () -> Self) {
            self = content()
        }
    }
    
    @resultBuilder
    struct PropertyBuilder {
        public static func buildBlock(
            _ returns: any TypeDeclare
        ) -> PropertyDeclare {
            .init(returns: returns)
        }
    }
    
    @resultBuilder
    struct FunctionBuilder {
        public static func buildBlock(
            _ returns: any TypeDeclare,
            _ argument: ArgumentDeclare
        ) -> FunctionDeclare {
            .init(returns: returns, argument: argument)
        }
    }

    enum OperationDeclare {
        public struct Prefix: Sendable {
            public let selfNullable: Bool
            public let returns: any TypeDeclare
            
            init(
                returns: any TypeDeclare,
                selfNullable: Bool
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
            }
            
            public init(@PrefixBuilder _ content: () -> Self) {
                self = content()
            }
        }

        public struct Suffix: Sendable {
            public let selfNullable: Bool
            public let returns: any TypeDeclare
            
            init(
                returns: any TypeDeclare,
                selfNullable: Bool
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
            }
            
            public init(@SuffixBuilder _ content: () -> Self) {
                self = content()
            }
        }

        public struct Infix: Sendable {
            public let selfNullable: Bool
            public let returns: any TypeDeclare
            public let right: any TypeDeclare
            
            init(
                returns: any TypeDeclare,
                selfNullable: Bool,
                right: any TypeDeclare
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
                self.right = right
            }
            
            public init(@InfixBuilder _ content: () -> Self) {
                self = content()
            }
        }
        
        @resultBuilder
        public struct InfixBuilder {
            public static func buildBlock(
                _ returns: any TypeDeclare,
                _ selfNullable: Bool,
                _ right: any TypeDeclare
            ) -> OperationDeclare.Infix {
                .init(returns: returns, selfNullable: selfNullable, right: right)
            }
        }

        @resultBuilder
        public struct PrefixBuilder {
            public static func buildBlock(
                _ returns: any TypeDeclare,
                _ selfNullable: Bool
            ) -> OperationDeclare.Prefix {
                .init(returns: returns, selfNullable: selfNullable)
            }
        }

        @resultBuilder
        public struct SuffixBuilder {
            public static func buildBlock(
                _ returns: any TypeDeclare,
                _ selfNullable: Bool
            ) -> OperationDeclare.Suffix {
                .init(returns: returns, selfNullable: selfNullable)
            }
        }
    }

    static func Return(_ type: @Sendable @escaping () -> any TypeDeclare) -> any TypeDeclare { type() }
}
